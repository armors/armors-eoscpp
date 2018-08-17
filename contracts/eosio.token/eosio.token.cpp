/**
 *  @file
 *  @copyright defined in eos/LICENSE.txt
 */

#include "eosio.token.hpp"

namespace eosio {

void token::create( account_name issuer,
                    asset        maximum_supply )
{
    require_auth( _self );

    auto sym = maximum_supply.symbol;

    eosio_assert( sym.is_valid(), "invalid symbol name" );
    eosio_assert( maximum_supply.is_valid(), "invalid supply");
    eosio_assert( maximum_supply.amount > 0, "max-supply must be positive");

    stats statstable( _self, sym.name() );
    auto existing = statstable.find( sym.name() );
    eosio_assert( existing == statstable.end(), "token with symbol already exists" );

    statstable.emplace( _self, [&]( auto& s ) {
       s.supply.symbol = maximum_supply.symbol;
       s.max_supply    = maximum_supply;
       s.issuer        = issuer;
       s.pause         = false;
    });
}


void token::issue( account_name to,
                  asset         quantity,
                  string        memo )
{
    auto sym = quantity.symbol;
    eosio_assert( sym.is_valid(), "invalid symbol name" );
    eosio_assert( memo.size() <= 256, "memo has more than 256 bytes" );

    auto sym_name = sym.name();
    stats statstable( _self, sym_name );
    auto existing = statstable.find( sym_name );
    eosio_assert( existing != statstable.end(), "token with symbol does not exist, create token before issue" );
    const auto& st = *existing;
    eosio_assert( st.pause == false, "token is paused" );
    require_auth( st.issuer );
    eosio_assert( quantity.is_valid(), "invalid quantity" );
    eosio_assert( quantity.amount > 0, "must issue positive quantity" );

    eosio_assert( quantity.symbol == st.supply.symbol, "symbol precision mismatch" );
    eosio_assert( quantity.amount <= st.max_supply.amount - st.supply.amount, "quantity exceeds available supply");

    statstable.modify( st, 0, [&]( auto& s ) {
       s.supply += quantity;
    });

    add_balance( st.issuer, quantity, st.issuer );

    if( to != st.issuer ) {
       SEND_INLINE_ACTION( *this, transfer, {st.issuer,N(active)}, {st.issuer, to, quantity, memo} );
    }
}

void token::transfer( account_name from,
                      account_name to,
                      asset        quantity,
                      string       memo )
{
    eosio_assert( from != to, "cannot transfer to self" );
    require_auth( from );
    eosio_assert( is_account( to ), "to account does not exist");
    auto sym = quantity.symbol.name();
    stats statstable( _self, sym );
    const auto& st = statstable.get( sym );

    require_recipient( from );
    require_recipient( to );
    eosio_assert( st.pause == false, "token is paused" );
    eosio_assert( quantity.is_valid(), "invalid quantity" );
    eosio_assert( quantity.amount > 0, "must transfer positive quantity" );
    eosio_assert( quantity.symbol == st.supply.symbol, "symbol precision mismatch" );
    eosio_assert( memo.size() <= 256, "memo has more than 256 bytes" );


    sub_balance( from, quantity );
    add_balance( to, quantity, from );
}

void token::sub_balance( account_name owner, asset value ) {
   accounts from_acnts( _self, owner );

   const auto& from = from_acnts.get( value.symbol.name(), "no balance object found" );
   eosio_assert( from.balance.amount >= value.amount, "overdrawn balance" );


   if( from.balance.amount == value.amount ) {
      from_acnts.erase( from );
   } else {
      from_acnts.modify( from, owner, [&]( auto& a ) {
          a.balance -= value;
      });
   }
}

void token::add_balance( account_name owner, asset value, account_name ram_payer )
{
   accounts to_acnts( _self, owner );
   auto to = to_acnts.find( value.symbol.name() );
   if( to == to_acnts.end() ) {
      to_acnts.emplace( ram_payer, [&]( auto& a ){
        a.balance = value;
      });
   } else {
      to_acnts.modify( to, 0, [&]( auto& a ) {
        a.balance += value;
      });
   }
}

void token::pause( bool pause, asset value )
{
    symbol_name sym_name = value.symbol.name();

    stats statstable( _self, sym_name );
    auto existing = statstable.find( sym_name );
    eosio_assert( existing != statstable.end(), "token with symbol does not exist, create token before pause" );
    const auto& st = *existing;

    require_auth( st.issuer );

    statstable.modify( st, 0, [&]( auto& s ) {
       s.pause = pause;
    });
}

void token::timelock( account_name beneficiary,
                      asset        lock_asset,
                      uint64_t     release_time )
{
    auto sym = lock_asset.symbol;
    eosio_assert( sym.is_valid(), "invalid symbol name" );

    auto sym_name = sym.name();
    stats statstable( _self, sym_name );
    auto existing = statstable.find( sym_name );
    eosio_assert( existing != statstable.end(), "token with symbol does not exist, create token before lock" );
    const auto& st = *existing;
    eosio_assert( st.pause == false, "token is paused" );
    require_auth( st.issuer );

    eosio_assert( lock_asset.is_valid(), "invalid asset" );
    eosio_assert( lock_asset.amount > 0, "must lock positive asset" );

    eosio_assert( lock_asset.symbol == st.supply.symbol, "symbol precision mismatch" );
    eosio_assert( lock_asset.amount <= st.max_supply.amount - st.supply.amount, "lock asset exceeds available supply");

    statstable.modify( st, 0, [&]( auto& s ) {
       s.lock_supply += lock_asset;
       s.supply += lock_asset;
    });

    lock_assets( beneficiary, lock_asset, release_time );
}


void token::lock_assets( account_name beneficiary,
                        asset        lock_asset,
                        uint64_t     release_time )
{
    depositorys depos_table( _self, lock_asset.symbol.name() );

    depos_table.emplace( _self, [&]( auto& a ){
      a.id = depos_table.available_primary_key();
      a.lock_asset = lock_asset;
      a.beneficiary = beneficiary;
      a.release_time = release_time;
    });
}

void token::release(account_name beneficiary_name,
                    asset        lock_asset )
{
  auto sym = lock_asset.symbol;
  eosio_assert( sym.is_valid(), "invalid symbol name" );

  auto sym_name = sym.name();

  stats statstable( _self, sym_name );

  auto existing = statstable.find( sym_name );
  eosio_assert( existing != statstable.end(), "token with symbol does not exist, create token before release" );
  const auto& st = *existing;

  depositorys depos_table( _self, sym_name );

  auto beneficiary_index = depos_table.get_index<N(bybeneficiary)>();

  auto benefi_itr = beneficiary_index.find(beneficiary_name);

  while (benefi_itr != beneficiary_index.end() && benefi_itr->beneficiary == beneficiary_name) {

    if(lock_asset.symbol == benefi_itr->lock_asset.symbol){

        if(now() < benefi_itr->release_time){
          continue;
        }

        add_balance( st.issuer, benefi_itr->lock_asset, st.issuer );

        if( beneficiary_name != st.issuer ) {
           SEND_INLINE_ACTION( *this, transfer, {st.issuer,N(active)}, {st.issuer, beneficiary_name, benefi_itr->lock_asset, "unlock asset"} );
        }

        statstable.modify( st, 0, [&]( auto& s ) {
           s.lock_supply -= benefi_itr->lock_asset;
        });

        benefi_itr = beneficiary_index.erase(benefi_itr);

    }else{
        benefi_itr++;
    }
  }

}


} /// namespace eosio

EOSIO_ABI( eosio::token, (create)(issue)(transfer)(pause)(timelock)(release) )
