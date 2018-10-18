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

    run_cmd "sh eos.sh cli 'wallet create -n $name --to-console' > $project_docker_persistent_dir/wallets/${name}.password"
    run_cmd "sh eos.sh cli 'wallet import -n $name --private-key 5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3'"

    _default_key

  fi
}

function _default_key()
{
    key_create
    key_create
    key_create
    key_create
    key_create

    key_create
    key_create
    key_create
    key_create
    key_create
}


function _get_public_key()
{
  local line=$1

  local keys=`sed -n ${line}p $project_docker_persistent_dir/wallets/wallets.key`
  #local key=${keys##'EOS'}
  local key=${keys##*'public key of: "'}

  echo ${key%'"'*}
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
    local name="$developer_name"_"wallet"
    run_cmd "sh eos.sh cli 'wallet create_key -n $name' >> $project_docker_persistent_dir/wallets/wallets.key"
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
