// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IFuelMessageOutbox} from "./IFuelMessageOutbox.sol";

/// @title FuelMessageSender
/// @notice Helper contract for contracts sending messages to Fuel
contract FuelMessageSender {
    ///////////////
    // Constants //
    ///////////////

    /// @notice FuelMessageOutbox contract used to send messages to Fuel
    address public immutable FUEL_OUTBOX;

    /////////////////
    // Constructor //
    /////////////////

    /// @notice Contract constructor to setup immutable values
    /// @param fuelOutbox Address of the FuelMessageOutbox contract
    constructor(address fuelOutbox) {
        FUEL_OUTBOX = fuelOutbox;
    }

    ////////////////////////
    // Internal Functions //
    ////////////////////////

    /// @notice Send a message to a recipient on Fuel
    /// @param recipient The target message receiver
    /// @param data The message data to be sent to the receiver
    function sendFuelMessage(bytes32 recipient, bytes memory data) internal {
        IFuelMessageOutbox(FUEL_OUTBOX).sendMessage(recipient, data);
    }

    /// @notice Send a message to a recipient on Fuel
    /// @param recipient The target message receiver
    /// @param amount The amount of ETH to send with message
    /// @param data The message data to be sent to the receiver
    function sendFuelMessage(
        bytes32 recipient,
        uint256 amount,
        bytes memory data
    ) internal {
        IFuelMessageOutbox(FUEL_OUTBOX).sendMessage{value: amount}(
            recipient,
            data
        );
    }

    /// @notice Send a message to a recipient on Fuel
    /// @param recipient The target message receiver
    /// @param owner The owner predicate required to play message
    /// @param data The message data to be sent to the receiver
    function sendFuelMessageWithOwner(
        bytes32 recipient,
        bytes32 owner,
        bytes memory data
    ) internal {
        IFuelMessageOutbox(FUEL_OUTBOX).sendMessageWithOwner(
            recipient,
            owner,
            data
        );
    }

    /// @notice Send a message to a recipient on Fuel
    /// @param recipient The target message receiver
    /// @param owner The owner predicate required to play message
    /// @param amount The amount of ETH to send with message
    /// @param data The message data to be sent to the receiver
    function sendFuelMessageWithOwner(
        bytes32 recipient,
        bytes32 owner,
        uint256 amount,
        bytes memory data
    ) internal {
        IFuelMessageOutbox(FUEL_OUTBOX).sendMessageWithOwner{value: amount}(
            recipient,
            owner,
            data
        );
    }
}
