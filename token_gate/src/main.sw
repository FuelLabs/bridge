contract;

dep fungible_token_abi;
dep gateway_abi;

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
    token::{mint_to, burn},
    tx::{tx_inputs_count, tx_input_pointer, tx_input_type},
    // u256::U256,
    vm::evm::evm_address::EvmAddress,
};

use fungible_token_abi::FungibleToken;
use gateway_abi::L2ERC20Gateway;


////////////////////////////////////////
// Constants
////////////////////////////////////////

// @todo update with actual predicate root
const PREDICATE_ROOT = 0x0000000000000000000000000000000000000000000000000000000000000000;
const NAME = "PLACEHOLDER";
const SYMBOL = "PLACEHOLDER";
const DECIMALS = 18;
// @todo update with actual L1 token address
const LAYER_1_TOKEN = 0x0000000000000000000000000000000000000000000000000000000000000000;
const LAYER_1_DECIMALS = 18;

// @todo use consts in stdlib when added
const INPUT_COIN = 0u8;
const INPUT_CONTRACT = 1u8;
const INPUT_MESSAGE = 2u8;
const OUTPUT_CONTRACT = 1u8;
const OUTPUT_CHANGE = 3u8;
const OUTPUT_VARIABLE = 4u8;


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
    refund_amounts: StorageMap<(b256, b256), u64>,
}

////////////////////////////////////////
// Helper functions
////////////////////////////////////////

// @todo use general form tx_input_owner() when it lands in stdlib
// fn tx_input_message_owner(input_ptr: u32) -> Address {
//     let owner_addr = ~Address::from(asm(buffer, ptr: input_ptr) {
//         // Need to skip over 17? words, so add 8*18=144
//         addi ptr ptr i144;
//         // Save old stack pointer
//         move buffer sp;
//         // Extend stack by 32 bytes
//         cfei i32;
//         // Copy 32 bytes
//         mcpi buffer ptr i32;
//         // `buffer` now points to the 32 bytes
//         buffer: b256
//     });

//     owner_addr
// }

/// If the input's type is `InputCoin` or `InputMessage`,
/// return the owner as an Option::Some(owner).
/// Otherwise, returns Option::None.
pub fn tx_input_owner(input_ptr: u32) -> Option<Address> {
    let type = tx_input_type(input_ptr);
    let owner_offset = match type {
        0u8 => {
            // Need to skip over six words, so add 8*6=48
            48
        },
        2u8 => {
            // Need to skip over eighteen words, so add 8*18=144
            144
        },
        _ => {
            return Option::None;
        },
    };

    Option::Some(~Address::from(asm(
        buffer,
        ptr: input_ptr,
        offset: owner_offset) {
            // Need to skip over `offset` words
            add ptr ptr offset;
            // Save old stack pointer
            move buffer sp;
            // Extend stack by 32 bytes
            cfei i32;
            // Copy 32 bytes
            mcpi buffer ptr i32;
            // `buffer` now points to the 32 bytes
            buffer: b256
        }
    ))

}

/// Get the type of an input at a given index
// @todo extract to stdlib
fn input_type(index: u8) -> u8 {
    let ptr = tx_input_pointer(index);
    let input_type = tx_input_type(ptr);
    input_type
}

/// Check if the owner of an InputMessage matches PREDICATE_ROOT
fn authenticate_message_owner(input_ptr: u32) -> bool {
    let owner = tx_input_owner(input_ptr).unwrap();
    if owner.into() == PREDICATE_ROOT {
        true
    } else {
        false
    }
}

fn parse_message_data(input_ptr: u32) -> MessageData {
    // @todo replace dummy data with the real values
    MessageData {
        asset: 0x0000000000000000000000000000000000000000000000000000000000000000,
        fuel_token: contract_id(),
        to: Identity::Address(~Address::from(0x0000000000000000000000000000000000000000000000000000000000000000)),
        amount: 42
    }
}

////////////////////////////////////////
// Errors
////////////////////////////////////////

enum TokenGatewayError {
    CannotReinitialize: (),
    ContractNotInitialized: (),
    IncorrectAssetAmount: (),
    IncorrectAssetDeposited: (),
    UnauthorizedUser: (),
    NoCoinsForwarded: (),
    IncorrectMessageOwner: (),
}

////////////////////////////////////////
// Events
////////////////////////////////////////

pub struct MintEvent {
    to: Identity,
    amount: u64,
}

pub struct BurnEvent {
    // from: Identity,
    amount: u64,
}

struct WithdrawalEvent {
    to: Identity,
    amount: u64,
    asset: ContractId,
}

////////////////////////////////////////
// ABI Implementations
////////////////////////////////////////

impl FungibleToken for Contract {
    ///  owner is the L1ERC20Gateway contract ?
    #[storage(read, write)]
    fn constructor(owner: Identity) {
        require(storage.initialized == false, TokenGatewayError::CannotReinitialize);
        storage.owner = owner;
        storage.initialized = true;
    }

    #[storage(read, write)]
    fn mint(to: Identity, amount: u64) {
        let sender: Result<Identity, AuthError> = msg_sender();
        require(sender.unwrap() == storage.owner, TokenGatewayError::UnauthorizedUser);
        mint_to(amount, to);
        log(MintEvent {to, amount});
    }

    // @todo decide if this needs to be public
    #[storage(read, write)]
    fn burn(amount: u64) {
        require(msg_sender().unwrap() == storage.owner, TokenGatewayError::UnauthorizedUser);
        require(contract_id() == msg_asset_id(), TokenGatewayError::IncorrectAssetDeposited);
        require(amount == msg_amount(), TokenGatewayError::IncorrectAssetAmount);

        burn(amount);
        // @todo consider adding msg_sender to log as a `from` field
        log(BurnEvent {amount});
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
}

impl L2ERC20Gateway for Contract {
    fn withdraw_refund(originator: Identity) {
        // check storage mapping refund_amounts first
        // if valid, transfer to originator
        // @todo consider if anyone can call this, or only the originalto themselves
    }

    /// Withdraw coins back to L1 and burn the corresponding amount of coins
    /// on L2.
    ///
    /// # Arguments
    ///
    /// * `to` - the destination of the transfer (an Address or a ContractId)
    ///
    /// # Reverts
    ///
    /// * When no coins were sent with call
    fn withdraw_to(to: Identity) {
        let withdrawal_amount = msg_amount();

        // @todo review requirement
        require(withdrawal_amount != 0, TokenGatewayError::NoCoinsForwarded);

        let origin_contract_id = msg_asset_id();
        let token_contract = abi(FungibleToken, origin_contract_id.into());

        token_contract.burn{
            coins: withdrawal_amount,
            asset_id: origin_contract_id.into()
        } (withdrawal_amount);

        // for now, use a dummy message type to allow testing until real message inputs are implemented.
        // Output a message to release tokens locked on L1
        // @todo implement me!
        // send_message(...);

        log(WithdrawalEvent {
            to: to,
            amount: withdrawal_amount,
            asset: origin_contract_id,
        });
    }

    #[storage(read, write)]
    fn finalize_deposit() {
        // The finalize_deposit() mainly just has to check that the value sent (which was a bigint) can fit inside a uint64 (needs to be passed as a Sway U256 !)
        // and that the ERC20 deposited matches what the contract expects. Otherwise, it needs to make a note of any refunds due, so that the ERC20 can be returned on the Ethereum side.


        // verify msg_sender is the L1ERC20Gateway contract
        let sender = msg_sender().unwrap();
        // @todo review requirement
        require(sender == storage.owner, TokenGatewayError::UnauthorizedUser);

        // @todo review requirement
        assert(input_type(1) == INPUT_MESSAGE);

        // we know the index where the InpuptMessage should be located
        let input_pointer = tx_input_pointer(1);

        // check that InputMessage.owner == predicate root
        require(authenticate_message_owner(input_pointer), TokenGatewayError::IncorrectMessageOwner);

        // Parse message data (asset: ContractId, fuel_token: ContractId, to: Identity, amount: u64)
        let message_data = parse_message_data(input_pointer);

        // verify asset matches hardcoded L1 token
        // @todo review requirement
        require(message_data.asset == LAYER_1_TOKEN, TokenGatewayError::IncorrectAssetDeposited);

        // start token mint process
        // @todo work out how to mint. i.e: have an internal function we can call here, which is also used byt the public `mint` function.
        // Also, we may want to have both `mint` and `mint_to` exposed by the token contract, but `mint_to` perhaps doesn't need to be part of the general token spec... (would probably need to expose the generic `transfer` in that case, which would cover more use-cases. Under the hood, `mint` could be made to utilize `mint_to` or not, as needed by the specific token.
        // let tokengate = abi(FungibleToken, contract_id());

        // @note for now, we've decided to mint_to only to EOA's, which can later be extended to mint to either (Identity)
        // if ! mint_deposit_amount(message_data.amount, message_data.to) {
        //     // if mint fails or is invalid for any reason (i.e: precision), register it to be refunded later

        // } else {
        //     log(
        //         MintEvent {
        //             amount: message_data.amount,
        //             to: message_data.to,
        //         }
        //     )
        // }
    }

    fn layer1_token() -> Address {
        ~Address::from(LAYER_1_TOKEN)
    }

    fn layer1_decimals() -> u8 {
        LAYER_1_DECIMALS
    }
}