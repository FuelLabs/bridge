predicate;

use std::address::Address;
use std::tx::*;
use std::assert::assert;
use std::hash::*;
use std::contract_id::ContractId;

/// Get the ID of a contract input
fn get_input_contract_id(index: u8) -> ContractId {
    // Check that input at this index is a contract input
    assert(get_input_type(index) == 1u8);

    let ptr = tx_input_pointer(index);
    let contract_id_bytes = asm(r1, r2: ptr) {
        lw r1 r2 i200;
        r1: b256
    };
    ~ContractId::from(contract_id_bytes)
}

/// Get the type of an input at a given index
fn get_input_type(index: u8) -> u8 {
    let ptr = tx_input_pointer(index);
    let input_type = tx_input_type(ptr);
    input_type
}

/// Get the type of an input at a given index
fn get_output_type(index: u8) -> u8 {
    let ptr = tx_output_pointer(index);
    let output_type = tx_output_type(ptr);
    output_type
}

/// Get the script spending the input belonging to this predicate hash. TO DO : replace with std-lib version when ready
fn get_script<T>() -> T {
    let script_ptr = std::context::registers::instrs_start();
    let script = asm(r1: script_ptr) {
        r1: T
    };
    script
}

/// Predicate verifying a message input is being spent according to the rules for a valid deposit
fn main() -> bool {
    /////////////////
    /// CONSTANTS ///
    /////////////////

    // TO DO: hard code actual constants

    // The contract ID of the deposited token
    const TOKEN_CONTRACT_ID = ~ContractId::from(0x1010101010101010101010101010101010101010101010101010101010101010);
    // The minimum gas limit for the transaction not to revert out-of-gas.
    const MIN_GAS = 42;
    // The hash of the script which must spend the input belonging to this predicate
    const SPENDING_SCRIPT_HASH = 0x032994634d35b1e42147b505f545a8677b2849d8a733fbe502a4b6b60621c474;

    //////////////////
    /// CONDITIONS ///
    //////////////////

    // Verify script bytecode hash is expected
    let script: [byte;
    252] = get_script(); // Note : Make sure 252 equal to actual compiled script length
    let script_hash = sha256(script);
    assert(script_hash == SPENDING_SCRIPT_HASH);

    // Verify gas limit is high enough
    let gasLimit = tx_gas_limit();
    assert(gasLimit >= MIN_GAS);

    // Transaction must have exactly three inputs: a Coin input (for fees), a Message, and the token Contract (in that order)
    // TO DO: is there a more readable/maintainable way to manage input/output types in Sway, rather than having to know the integer identifier of each type?
    let n_inputs = tx_inputs_count();
    assert(n_inputs == 3 && get_input_type(0) == 0u8 && get_input_type(1) == 2u8 && get_input_contract_id(3) == TOKEN_CONTRACT_ID);

    // Transation must have exactly 2 outputs: OutputVariable and OutputContract (in that order)
    let n_outputs = tx_outputs_count();
    assert(n_outputs == 2 && get_output_type(0) == 4u8 && get_output_type(1) == 1u8); // Single output is OutputVariable

    true
}