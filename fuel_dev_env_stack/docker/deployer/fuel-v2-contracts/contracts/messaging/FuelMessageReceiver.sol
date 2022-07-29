// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IFuelMessageInbox} from "./IFuelMessageInbox.sol";

/// @title FuelMessageReceiver
/// @notice Helper contract for contracts receiving messages to Fuel
contract FuelMessageReceiver {
    ///////////////
    // Constants //
    ///////////////

    /// @notice FuelMessageInbox contract used to recieve messages from Fuel
    address public immutable FUEL_INBOX;

    ////////////////////////
    // Function Modifiers //
    ////////////////////////

    /// @notice Enforces that the modified function is only callable by the Fuel inbox
    modifier onlyFromInbox() {
        require(msg.sender == FUEL_INBOX, "Caller is not the inbox");
        _;
    }

    /// @notice Enforces that the modified function is only callable by the inbox and a specific Fuel account
    /// @param fuelSender The only sender on Fuel which is authenticated to call this function
    modifier onlyFromFuelSender(bytes32 fuelSender) {
        require(msg.sender == FUEL_INBOX, "Caller is not the inbox");
        require(
            IFuelMessageInbox(FUEL_INBOX).getMessageSender() == fuelSender,
            "Invalid message sender"
        );
        _;
    }

    /////////////////
    // Constructor //
    /////////////////

    /// @notice Contract constructor to setup immutable values
    /// @param fuelInbox Address of the FuelMessageInbox contract
    constructor(address fuelInbox) {
        FUEL_INBOX = fuelInbox;
    }
}
