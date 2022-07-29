// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @notice The Fuel Message Inbox contract relays messages sent from Fuel
struct OutputMessageProof {
    bytes32 root;
    uint256 key;
    uint256 numLeaves;
    bytes32[] proof;
}

/// @title FuelMessageInbox
/// @notice The Fuel Message Inbox contract relays messages sent from Fuel
interface IFuelMessageInbox {
    ////////////
    // Events //
    ////////////

    /// @notice Emitted when a Message is successfully relayed from Fuel
    event RelayedMessage(bytes32 indexed messageId);

    //////////////////////
    // Public Functions //
    //////////////////////

    /// @notice Used by message receiving contracts to get the address on Fuel that sent the message
    function getMessageSender() external view returns (bytes32);

    /// @notice Relays a message published on Fuel
    /// @param sender The address sending the message
    /// @param recipient The receiving address
    /// @param amount The value amount to send with message
    /// @param nonce The inbox message nonce
    /// @param data The ABI of the call to make to the receiver
    /// @param merkleProof Merkle proof to prove this message is valid
    function relayMessage(
        bytes32 sender,
        bytes32 recipient,
        bytes32 nonce,
        uint64 amount,
        bytes calldata data,
        OutputMessageProof calldata merkleProof
    ) external payable;
}
