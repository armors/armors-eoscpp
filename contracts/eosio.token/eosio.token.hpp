/**
 *  @file
 *  @copyright defined in eos/LICENSE.txt
 */
#pragma once

#include <eosiolib/asset.hpp>
#include <eosiolib/eosio.hpp>

#include <string>

namespace eosiosystem {
   class system_contract;
}

namespace eosio {

   using std::string;

   class token : public contract {
      public:
         token( account_name self ):contract(self){}

         void create( account_name issuer, asset maximum_supply);

         void issue( account_name to, asset quantity, string memo );

         void transfer( account_name from, account_name to, asset quantity, string memo );

         inline asset get_supply( symbol_name sym )const;

         inline asset get_balance( account_name owner, symbol_name sym )const;

         void pause( bool pause, asset value );

         void timelock( account_name beneficiary, asset lock_asset, uint64_t release_time );

         void release( account_name beneficiary, asset lock_asset );

      private:

         ///@abi table accounts i64
         struct account {
           asset balance;
           uint64_t primary_key()const { return balance.symbol.name(); }
         };

         ///@abi table stats i64
         struct currency {
            asset          supply;
            asset          lock_supply;
            asset          max_supply;
            account_name   issuer;
            bool           pause;

            uint64_t primary_key()const { return supply.symbol.name(); }
         };

         ///@abi table depository i64
         struct depository {
           uint64_t     id;
           asset        lock_asset;
           account_name beneficiary;
           uint64_t     release_time;

           uint64_t primary_key()const { return id; }
           account_name get_beneficiary() const { return beneficiary; }
         };

         //typedef eosio::multi_index< tablename,  typename> table( code, scope);
         typedef eosio::multi_index<N(accounts), account> accounts;
         typedef eosio::multi_index<N(stat), currency> stats;
         typedef eosio::multi_index<N(depository), depository, indexed_by< N(bybeneficiary), const_mem_fun<depository, account_name, &depository::get_beneficiary> > > depositorys;

         void sub_balance( account_name owner, asset value );
         void add_balance( account_name owner, asset value, account_name ram_payer );
         void lock_assets( account_name beneficiary, asset lock_asset, uint64_t release_time );

      public:
         struct transfer_args {
            account_name  from;
            account_name  to;
            asset         quantity;
            string        memo;
         };
   };

   asset token::get_supply( symbol_name sym )const
   {
      stats statstable( _self, sym );
      const auto& st = statstable.get( sym );
      return st.supply;
   }

   asset token::get_balance( account_name owner, symbol_name sym )const
   {
      accounts accountstable( _self, owner );
      const auto& ac = accountstable.get( sym );
      return ac.balance;
   }

} /// namespace eosio
