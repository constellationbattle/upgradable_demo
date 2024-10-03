contract;

use standards::src5::State;

abi OwnedProxy {

    #[storage(write)]
    fn set_proxy_owner(new_proxy_owner: State);

}

abi Counter {
    #[storage(read, write)]
    fn increment(amount: u64) -> u64;

    #[storage(read, write)]
    fn add_double(amount: u64) -> u64;

    #[payable, storage(read, write)]
    fn pay_eth();

    #[storage(read, write)]
    fn claim_admin(_amount: u64);

    #[storage(read, write)]
    fn claim_deposite(_amount: u64);

    #[storage(read)]
    fn get() -> u64;

    #[storage(read)]
    fn get_msg_send() -> Identity;

    #[storage(read)]
    fn get_my_deposite() -> Option<u64>;
}

use ::sway_libs::{
    ownership::errors::InitializationError,
    upgradability::{
        _proxy_owner,
        _proxy_target,
        _set_proxy_owner,
        _set_proxy_target,
        only_proxy_owner,
    },
};
use standards::{src14::{SRC14, SRC14Extension}};
use std::execution::run_external;
use std::{
    auth::msg_sender,
    call_frames::msg_asset_id,
    constants::ZERO_B256,
    constants::DEFAULT_SUB_ID,
    context::msg_amount,
    asset::*,
    hash::*,
};

enum AssetError {
    InsufficientPayment: (),
    IncorrectAssetSent: (),
}


storage {
    counter: u64 = 0,
    mydeposite: StorageMap<Identity, u64> = StorageMap {},
}

impl SRC14 for Contract {

    #[storage(read, write)]
    fn set_proxy_target(new_target: ContractId) {
        only_proxy_owner();
        _set_proxy_target(new_target);
    }

    #[storage(read)]
    fn proxy_target() -> Option<ContractId> {
        _proxy_target()
    }
}

impl SRC14Extension for Contract {
    
    #[storage(read)]
    fn proxy_owner() -> State {
        _proxy_owner()
    }
}

impl OwnedProxy for Contract {

    #[storage(write)]
    fn set_proxy_owner(new_proxy_owner: State) {
        only_proxy_owner();
        _set_proxy_owner(new_proxy_owner);
    }
}

impl Counter for Contract {
    #[storage(read, write)]
    fn increment(amount: u64) -> u64 {
        let incremented = storage.counter.read() + amount;
        storage.counter.write(incremented);
        incremented
    }

    #[storage(read, write)]
    fn add_double(amount: u64) -> u64 {
        only_proxy_owner();
        let incremented = storage.counter.read() + amount*2;
        storage.counter.write(incremented);
        incremented
    }

    #[payable]
    #[storage(read, write)]
    fn pay_eth(){
        // Verify payment
        require(AssetId::base() == msg_asset_id(), AssetError::IncorrectAssetSent);
        if msg_amount() > 0 {
            storage.mydeposite.insert(msg_sender().unwrap(), msg_amount());
        }
    }

    #[storage(read, write)]
    fn claim_admin(_amount: u64){
        only_proxy_owner();
        transfer(msg_sender().unwrap(), AssetId::base(), _amount);
    }
    
    #[storage(read, write)]
    fn claim_deposite(_amount: u64){
        let amount = storage.mydeposite.get(msg_sender().unwrap()).try_read();
        require(amount.is_some(),
            AssetError::InsufficientPayment,
        );
        let mut amount_ = amount.unwrap();
        require(amount_ >= _amount,
           AssetError::InsufficientPayment,
        );
        transfer(msg_sender().unwrap(), AssetId::base(), _amount);
        amount_ = amount_ - _amount;
        storage.mydeposite.insert(msg_sender().unwrap(), amount_);
    }


    #[storage(read)]
    fn get() -> u64 {
        storage.counter.read()
    }

    #[storage(read)]
    fn get_msg_send() -> Identity {
        msg_sender().unwrap()
    }

    #[storage(read)]
    fn get_my_deposite() -> Option<u64> {
        storage.mydeposite.get(msg_sender().unwrap()).try_read()
    }
}
