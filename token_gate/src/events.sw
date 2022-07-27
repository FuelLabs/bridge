library events;

use std::{
    contract_id::ContractId,
    identity::Identity,
};

pub struct MintEvent {
    from: Identity,
    amount: u64,
}

pub struct BurnEvent {
    from: Identity,
    amount: u64,
}

pub struct TransferEvent {
    from: Identity,
    to: Identity,
    amount: u64,
}

pub struct WithdrawalEvent {
    to: Identity,
    amount: u64,
    asset: ContractId,
}
