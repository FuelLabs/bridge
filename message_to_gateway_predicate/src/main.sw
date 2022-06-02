predicate;

use std::address::Address;
use std::tx::*;
use std::assert::assert;
use std::hash::*;
use std::contract_id::ContractId;

/// Get the destination address for coins to send for an output given a pointer to the output.
/// This method is only meaningful if the output type has the `to` field.
// TO DO: This should probably go in std::tx
fn get_output_to(ptr: u32) -> Address {
    let address_bytes = asm(r1, r2: ptr) {
        lw r1 r2 i8;
        r1: b256
    };

    ~Address::from(address_bytes)
}

// Get the ID of a contract input
fn get_input_contract_id(index: u8) -> ContractId {
    let ptr = tx_input_pointer(index);
    let contract_id_bytes = asm(r1, r2: ptr) {
        lw r1 r2 i200;
        r1: b256
    };
    ~ContractId::from(contract_id_bytes)
}

fn get_input_type(index: u8) -> u8 {
    let ptr = tx_input_pointer(index);
    let input_type = tx_input_type(ptr);
    input_type
}

// TO DO : replace with std-lib version when ready
fn get_script_data<T>() -> T {
    let script_length = std::tx::tx_script_length();
    let script_length = script_length + script_length % 8;

    let is = std::context::registers::instrs_start();
    let script_data_ptr = is + script_length;
    let script_data = asm(r1: script_data_ptr) {
        r1: T
    };
    script_data
}

// Anyone-can-spend predicate that only releases coins to a specified address
fn main(receiver: Address, gateway: ContractId, token: ContractId) -> bool {
    // Transaction must have only four inputs: a Coin input (for fees), a Message, the gateway Contract, and the token Contract (in that order)
    let n_inputs = tx_inputs_count();
    assert(
        n_inputs == 4 &&
        get_input_type(0) == 0u8 &&
        get_input_type(1) == 2u8 &&
        get_input_type(2) == 1u8 && get_input_contract_id(2) == gateway &&
        get_input_type(3) == 1u8 && get_input_contract_id(3) == token
        );

    // Verify a reasonable(?) amount of gas.
    const REASONABLE_GAS = 42;
    let gasLimit = tx_gas_limit();
    assert(gasLimit >= REASONABLE_GAS);

    // TO DO: Write script that must spend predicate so that len(script_data) and hash(script_data) can be hard-coded
    let script_data: [byte;
    100] = get_script_data(); // replace 100 with actual script length
    let script_data_hash = sha256(script_data);
    let EXPECTED_SCRIPT_HASH = 0x1010101010101010101010101010101010101010101010101010101010101010; // Hardcode hash of script that calls gateway with processMessage()
    assert(script_data_hash == EXPECTED_SCRIPT_HASH);

    // need to check if a == output.to for the Coin output. But can't loop in a predicate. Assume it's first output for now:
    let ptr = tx_output_pointer(0);
    let address = get_output_to(ptr);
    assert(address == receiver);

    true
}
