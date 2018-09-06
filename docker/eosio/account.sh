#!/bin/bash
set -e

function _account_create()
{
  local line=$1
  local public_key=$(_get_public_key $line)
  run_cmd "sh eos.sh cli 'create account eosio $2 $public_key $public_key'"
}

function _init_account()
{
  _open_un_lock_wallet

  _account_create 3 $developer_name
  # system
  _account_create 6 eosio.token
  _account_create 9 eosio.msig
  _account_create 12 eosio.bpay
  _account_create 15 eosio.names
  _account_create 18 eosio.ram
  _account_create 21 eosio.ramfee
  _account_create 24 eosio.saving
  _account_create 27 eosio.stake
  _account_create 30 eosio.vpay
}
