contract;

dep errors;
dep events;

use core::num::*;
use std::{
    address::Address,
    assert::{assert, require},
    chain::auth::{AuthError, msg_sender},
    context::{call_frames::{contract_id, msg_asset_id}, msg_amount},
    contract_id::ContractId,
    identity::Identity,
    logging::log,
    option::Option,
    result::Result,
    revert::revert,
    storage::StorageMap,
    token::{burn, mint, transfer_to_output},
    tx::{tx_input_pointer, tx_input_type, INPUT_MESSAGE},
    u256::U256,
    vm::evm::evm_address::EvmAddress,
};

use errors::TokenGatewayError;
use events::{BurnEvent, MintEvent, TransferEvent, WithdrawalEvent};
use gateway_abi::L2ERC20Gateway;

////////////////////////////////////////
// Constants
////////////////////////////////////////

// @todo update with actual predicate root
const PREDICATE_ROOT = 0x0000000000000000000000000000000000000000000000000000000000000000;
const NAME = "PLACEHOLDER";
const SYMBOL = "PLACEHOLDER";
const DECIMALS = 9u8;
// @todo update with actual L1 token address
const LAYER_1_TOKEN = ~EvmAddress::from(0x0000000000000000000000000000000000000000000000000000000000000000);
const LAYER_1_DECIMALS = 18u8;

////////////////////////////////////////
// Data
////////////////////////////////////////

struct MessageData {
    asset: b256,
    fuel_token: ContractId,
    to: Identity,
    amount: u64,
}

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////

storage {
    initialized: bool,
    owner: Identity,
    refund_amounts: StorageMap<(b256, b256), U256>,
}

////////////////////////////////////////
// Private functions
////////////////////////////////////////

fn parse_message_data(input_ptr: u32) -> MessageData {
    // @todo replace placeholder with stdlib getter using `gtf`
    let raw_data = GTF_INPUT_MESSAGE_DATA;

    // @todo replace dummy data with the real values
    MessageData {
        asset: 0x0000000000000000000000000000000000000000000000000000000000000000,
        fuel_token: contract_id(),
        to: Identity::Address(~Address::from(0x0000000000000000000000000000000000000000000000000000000000000000)),
        amount: 42
    }
}

// ref: https://github.com/FuelLabs/fuel-specs/blob/bd6ec935e3d1797a192f731dadced3f121744d54/specs/vm/instruction_set.md#smo-send-message-to-output
fn send_message(recipient: Address, coins: u64) {
    // @todo implement me!
}

fn transfer_tokens(amount: u64, asset: ContractId, to: Identity) {
    transfer_to_output(amount, asset, to)
}

#[storage(read)]
fn mint_tokens(amount: u64) -> bool {
    let sender = msg_sender().unwrap();
    require(sender == storage.owner, TokenGatewayError::UnauthorizedUser);
    mint(amount);
    log(MintEvent {from: msg_sender().unwrap(), amount});
    true
}

#[storage(read)]
fn burn_tokens(amount: u64) {
    let sender = msg_sender().unwrap();
    require(sender == storage.owner, TokenGatewayError::UnauthorizedUser);

    require(contract_id() == msg_asset_id(), TokenGatewayError::IncorrectAssetDeposited);
    require(amount == msg_amount(), TokenGatewayError::IncorrectAssetAmount);

    burn(amount);
    log(BurnEvent {from: msg_sender().unwrap(), amount})
}

////////////////////////////////////////
// ABI Implementations
////////////////////////////////////////

impl L2ERC20Gateway for Contract {
    #[storage(read, write)]
    fn constructor(owner: Identity) {
        require(storage.initialized == false, TokenGatewayError::CannotReinitialize);
        storage.owner = owner;
        storage.initialized = true;
    }

    #[storage(read, write)]
    // @review can anyone can call this, or only the originator themselves?
    fn claim_refund(originator: Identity, asset: ContractId) {
        // check storage mapping refund_amounts first
        // if valid, transfer to originator
        let inner_value = match originator {
            Identity::Address(a) => {
                a.value
            },
            Identity::ContractId(c) => {
                c.value
            },
        };

        let amount = storage.refund_amounts.get((inner_value, asset.into()));
        transfer_tokens(amount.as_u64().unwrap(), asset, originator);
    }

    fn withdraw_to(to: Identity) {
        let withdrawal_amount = msg_amount();
        // @todo review requirement
        require(withdrawal_amount != 0, TokenGatewayError::NoCoinsForwarded);

        let origin_contract_id = msg_asset_id();
        burn_tokens(withdrawal_amount);

        // Output a message to release tokens locked on L1
        send_message();

        log(WithdrawalEvent {
            to: to,
            amount: withdrawal_amount,
            asset: origin_contract_id,
        });
    }

    #[storage(read, write)]
    fn finalize_deposit() {
        // @review access control
        assert(tx_input_type(1) == INPUT_MESSAGE);

        // MessageInput should be located at index 1
        let input_pointer = tx_input_pointer(1);

        // @todo replace placeholders with stdlib getter using `gtf`
        let sender = GTF_INPUT_MESSAGE_SENDER;
        let owner = GTF_INPUT_MESSAGE_OWNER;

        // verify MessageInput.sender is the L1ERC20Gateway contract
        require(sender == L1ERC20Gateway, TokenGatewayError::UnauthorizedUser);

        // verify that MessageInput.owner == predicate root
        require(owner.into() == PREDICATE_ROOT, TokenGatewayError::IncorrectMessageOwner);

        // Parse message data
        let message_data = parse_message_data(input_pointer);

        // @review requirement
        // verify asset matches hardcoded L1 token
        require(message_data.asset == LAYER_1_TOKEN, TokenGatewayError::IncorrectAssetDeposited);

        // verify value sent as uint256 can fit inside a u64
        // if not, register a refund.
        let l1_amount = message_data.amount.as_u64();
        match l1_amount {
            Result::Err(e) => {
                storage.refund_amounts.insert((message_data.from, message_data.asset), message_data.amount);
                Result::Err(e)
            },
            Result::Ok(v) => {
                mint_tokens(v);
                transfer_tokens(v, contract_id(), message_data.from);

                // @review should this emit a DepositEvent instead to balance the WithdrawalEvent ?
                log(MintEvent {
                    amount: v,
                    to: message_data.to,
                });

                Result::Ok(())
            },
        }
    }

    fn name() -> str[11] {
        NAME
    }

    fn symbol() -> str[11] {
        SYMBOL
    }

    fn decimals() -> u8 {
        DECIMALS
    }

    fn layer1_token() -> EvmAddress {
        LAYER_1_TOKEN
    }

    fn layer1_decimals() -> u8 {
        LAYER_1_DECIMALS
    }
}
