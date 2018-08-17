#!/bin/bash
set -e

function _wallet_create()
{
  local _name;
  if [ ! -n "$1" ]; then
    _name='wallet'
  else
    _name=$1
  fi

  local name="$developer_name"_"$_name"
  if [ ! -f "$project_docker_persistent_dir/wallets/${name}.wallet" ]; then
    key_create
    key_create
    key_create
    key_create
    key_create

    key_create
    key_create

    run_cmd "sh eos.sh cli 'wallet create -n $name' > $project_docker_persistent_dir/wallets/${name}.password"
    run_cmd "sh eos.sh cli 'wallet import -n $name --private-key 5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3'"

    _wallet_import 2
    _wallet_import 5
    _wallet_import 8
    _wallet_import 11
    _wallet_import 14

  fi
}

function _wallet_import()
{
  local line=$1
  local keys=`sed -n ${line}p $project_docker_persistent_dir/wallets/wallets.key`
  local key=${keys##'Private key: '}

  run_cmd "sh eos.sh cli 'wallet import -n $name --private-key $key'"
}

function _get_private_key()
{
  local line=$1
  local keys=`sed -n ${line}p $project_docker_persistent_dir/wallets/wallets.key`
  local key=${keys##'Private key: '}

  echo $key
}

function _get_public_key()
{
  local line=$1
  local keys=`sed -n ${line}p $project_docker_persistent_dir/wallets/wallets.key`
  local key=${keys##'Public key: '}

  echo $key
}

function _get_password()
{
  local _name;
  if [ ! -n "$1" ]; then
    _name='wallet'
  else
    _name=$1
  fi

  local name="$developer_name"_"$_name"

  local passwords=`sed -n 5p $project_docker_persistent_dir/wallets/${name}.password`
  local password=$(echo $passwords|sed 's/"//g'|sed s/[[:space:]]//g);

  echo $password
}


function key_create()
{
  run_cmd "sh eos.sh cli 'create key' >> $project_docker_persistent_dir/wallets/wallets.key"
}

function _open_un_lock_wallet()
{
  local _name;
  if [ ! -n "$1" ]; then
    _name='wallet'
  else
    _name=$1
  fi

  local name="$developer_name"_"$_name"

  if [ ! -f "$project_docker_persistent_dir/wallets/${name}.wallet" ]; then
    echo "${name} wallet does not exist."
    exit;
  else
    run_cmd "sh eos.sh cli 'wallet open -n $name'"
    local pwd=$(_get_password)


    sh eos.sh cli "wallet unlock -n $name --password $pwd"
  fi
}


open_unlock_wallet(){
  local _name;
  if [ ! -n "$2" ]; then
    _name='wallet'
  else
    _name=$2
  fi
  _open_un_lock_wallet $_name
}
