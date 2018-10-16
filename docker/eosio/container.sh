#!/bin/bash
set -e

function run_eosio()
{
    _network_create

    local args='--restart=always'

    args="$args --cap-add SYS_PTRACE"

    args="$args -p $NODEOS_PORT:8888 --network eosdev"

    args="$args -v $project_path:$project_path"

    args="$args -w $project_path"

    args="$args -v $project_docker_runtime_dir/eosio/work:/work"

    args="$args -v $project_docker_runtime_dir/eosio/data:/mnt/dev/data"

    args="$args -v $project_docker_persistent_dir/nodeos:/mnt/dev/nodeos/config"

    args="$args -v $project_docker_persistent_dir/contracts:/mnt/dev/contracts"

    local cmd1="bash eos.sh send_cmd_to_eos_container 'cp -rf /contracts/* /mnt/dev/contracts'"

    run_cmd "docker run -d $args --name nodeos-$eosio_container $eosio_image \
    /bin/bash -c 'nodeos -d \
    /mnt/dev/data \
    --config-dir=/mnt/dev/nodeos/config \
    --http-server-address=0.0.0.0:8888 \
    --access-control-allow-origin=* --contracts-console --http-validate-host=false'; $cmd1"

    run_keosd
}


function run_keosd()
{
    local args='--restart=always'

    args="$args --cap-add SYS_PTRACE"

    args="$args -p 9876:9876 --network eosdev"

    args="$args -v $project_path:$project_path"

    args="$args -w $project_path"

    args="$args -v $project_docker_persistent_dir/keosd:/root/eosio-wallet"

    run_cmd "docker run -d $args --name keosd-$eosio_container $eosio_image /bin/bash -c 'keosd --http-server-address=0.0.0.0:9876'"
}

function rm_eosio()
{
    rm_container keosd-$eosio_container
    rm_container nodeos-$eosio_container
}

function send_cmd_to_eos_container()
{
    local cmd=$2
    run_cmd "docker exec -it nodeos-$eosio_container bash -c '$cmd'"
}

function cpp()
{
    local dir=$2
    local cmd=$3
    run_cmd "docker exec -it nodeos-$eosio_container bash -c 'cd $dir; eosiocpp $cmd'"
}

get_keosd_ip()
{
    local ip_keosd
    ip_keosd=`docker inspect --format='{{.NetworkSettings.Networks.eosdev.IPAddress}}' keosd-$eosio_container`
    echo ${ip_keosd};
}

function cli()
{
    local cmd=$2
    local ip=$(get_keosd_ip)
    run_cmd "docker exec -it nodeos-$eosio_container bash -c \"/opt/eosio/bin/cleos -u http://0.0.0.0:8888 --wallet-url http://$ip:9876 $cmd\""
}

function _init_contract()
{
    _open_un_lock_wallet
    run_cmd "sh eos.sh cli 'set contract eosio.token $project_docker_persistent_dir/contracts/eosio.token -x 1000s -p eosio.token@active'"
    _open_un_lock_wallet
    run_cmd "sh eos.sh cli 'set contract eosio.msig $project_docker_persistent_dir/contracts/eosio.msig -x 1000s -p eosio.msig@active'"
    _open_un_lock_wallet
    run_cmd "sh eos.sh cli 'set contract eosio $project_docker_persistent_dir/contracts/eosio.bios -x 1000s -p eosio@active'"
}

function _network_create()
{
    if (docker network ls|grep -q eosdev); then
        echo "network eosdev is created";
    else
        run_cmd "docker network create eosdev"
    fi
}