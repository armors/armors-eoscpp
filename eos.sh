#!/bin/bash

set -e

function read_kv_config()
{
    local file=$1
    local key=$2
    cat $file | grep "$key=" | awk -F '=' '{print $2}'
}

NODEOS_PORT=$(read_kv_config .env NODEOS_PORT)
VERSION=$(read_kv_config .env VERSION)

project_path=$(cd $(dirname $0); pwd -P)                            # 项目目录
project_docker_path="$project_path/docker-$VERSION"                 # 项目docker目录
source $project_docker_path/bash.sh                                 # 基础函数
developer_name=$('whoami');                                         # 开发者


app_basic_name=smart-contract
app="$developer_name-$app_basic_name"

eosio_image=hoseadevops/eos-dev:$VERSION

# container
eosio_container=$app-eosio

# container dir
project_eosio_dir="$project_docker_path/eos"
project_docker_eosio_dir="$project_docker_path/eosio"

project_docker_runtime_dir="$project_docker_path/runtime"           # app runtime
project_docker_persistent_dir="$project_docker_path/persistent"     # app persistent

#---------- eosio container ------------#
source $project_docker_path/eosio/container.sh
source $project_docker_path/eosio/wallet.sh
source $project_docker_path/eosio/account.sh
source $project_docker_path/eosio/contract.sh

function init()
{
    recursive_mkdir "$project_docker_persistent_dir/keosd"

    echo wallet_dir=$project_docker_persistent_dir/wallets > $project_docker_persistent_dir/config

    run_cmd "replace_template_key_value $project_docker_persistent_dir/config $project_docker_eosio_dir/conf/config.ini $project_docker_persistent_dir/keosd/config.ini"
}

function run()
{
    init
    run_eosio

    _wallet_create
    _init_account

    _init_contract
}

function restart()
{
    clean
    run
}

function clean()
{
    rm_eosio
    clean_runtime
    clean_persistent
}

function clean_runtime()
{
    run_cmd "rm -rf $project_docker_runtime_dir/eosio/config"
    run_cmd "rm -rf $project_docker_runtime_dir/eosio/data"
    run_cmd "rm -rf $project_docker_runtime_dir/eosio/work"
}

function clean_persistent()
{
  run_cmd "rm -f $project_docker_persistent_dir/config"
  run_cmd "rm -rf $project_docker_persistent_dir/keosd"
  run_cmd "rm -rf $project_docker_persistent_dir/contracts"
}


function help()
{
cat <<EOF
    Usage: sh eos.sh [options]

        Valid options are:

        run
        restart
        clean

        cpp
        cli

        open_unlock_wallet
        deploy

        key_create
        wallet_import
EOF
}

action=${1:-help}
ALL_COMMANDS="run restart clean cpp cli deploy key_create send_cmd_to_eos_container open_unlock_wallet key_create wallet_import"
list_contains ALL_COMMANDS "$action" || action=help
$action "$@"
