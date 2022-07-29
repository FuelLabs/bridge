// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title FuelMessageOutbox
/// @notice The Fuel Message Outbox contract sends messages from L1 to Fuel
interface IFuelMessageOutbox {
    ////////////
    // Events //
    ////////////

    /// @notice Emitted when a Message is sent from L1 to Fuel
    event SentMessage(
        bytes32 indexed sender,
        bytes32 indexed recipient,
        bytes32 owner,
        uint64 nonce,
        uint64 amount,
        bytes data
    );

    //////////////////////
    // Public Functions //
    //////////////////////

    /// @notice Send a message to a recipient on Fuel
    /// @param recipient The target message receiver
    /// @param data The message data to be sent to the receiver
    function sendMessage(bytes32 recipient, bytes memory data) external payable;

    /// @notice Send a message to a recipient on Fuel
    /// @param recipient The target message receiver
    /// @param owner The owner predicate required to play message
    /// @param data The message data to be sent to the receiver
    function sendMessageWithOwner(
        bytes32 recipient,
        bytes32 owner,
        bytes memory data
    ) external payable;

    /// @notice Send only ETH to the given recipient
    /// @param recipient The target message receiver
    function sendETH(bytes32 recipient) external payable;
}
