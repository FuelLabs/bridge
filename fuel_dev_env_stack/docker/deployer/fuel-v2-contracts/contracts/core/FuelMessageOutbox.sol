// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {FuelMessageInbox} from "./FuelMessageInbox.sol";
import {CryptographyLib} from "../lib/Cryptography.sol";
import {IFuelMessageOutbox} from "../messaging/IFuelMessageOutbox.sol";

/// @title FuelMessageOutbox
/// @notice The Fuel Message Outbox contract sends messages from L1 to Fuel
/// @dev This contract is to be deployed alongside FuelMessageInbox
contract FuelMessageOutbox is IFuelMessageOutbox, Ownable, Pausable {
    ///////////////
    // Constants //
    ///////////////

    /// @dev The number of decimals that the base Fuel asset uses
    uint256 public constant FUEL_BASE_ASSET_DECIMALS = 9;
    uint256 public constant ETH_DECIMALS = 18;

    /// @dev The max message data size in bytes
    uint256 public constant MAX_MESSAGE_DATA_SIZE = 2**16;

    /// @dev Address of the FuelMessageInbox
    FuelMessageInbox public immutable MESSAGE_INBOX;

    /////////////
    // Storage //
    /////////////

    /// @notice The default message owner predicate hash
    bytes32 public s_defaultMessagePredicate;

    /// @notice Nonce for the next message to be sent
    uint64 public s_messageNonce;

    /////////////////
    // Constructor //
    /////////////////

    /// @notice Contract constructor to setup immutable values and default values
    /// @param messageInbox Address of the FuelMessageInbox contract
    constructor(FuelMessageInbox messageInbox) Ownable() {
        MESSAGE_INBOX = messageInbox;
        //TODO: figure out good predicate hash to use here
        s_defaultMessagePredicate = bytes32(
            0x609a428d6498d9ddba812cc67c883a53446a1c01bc7388040f1e758b15e1d8bb
        );
        s_messageNonce = 0;
    }

    //////////////////////
    // Public Functions //
    //////////////////////

    /// @notice Pause outbound messages
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause outbound messages
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Set new default message owner predicate hash
    /// @param newMessagePredicate The new owner value to default messages with
    function setDefaultMessagePredicate(bytes32 newMessagePredicate)
        external
        onlyOwner
    {
        s_defaultMessagePredicate = newMessagePredicate;
    }

    /// @notice Send a message to a recipient on Fuel
    /// @param recipient The target message receiver
    /// @param data The message data to be sent to the receiver
    function sendMessage(bytes32 recipient, bytes memory data)
        external
        payable
        whenNotPaused
    {
        bytes32 owner = s_defaultMessagePredicate;
        _sendMessage(recipient, owner, data);
    }

    /// @notice Send a message to a recipient on Fuel
    /// @param recipient The target message receiver
    /// @param data The message data to be sent to the receiver
    /// @param owner The owner predicate required to play message
    function sendMessageWithOwner(
        bytes32 recipient,
        bytes32 owner,
        bytes memory data
    ) external payable whenNotPaused {
        _sendMessage(recipient, owner, data);
    }

    /// @notice Send only ETH to the given recipient
    /// @param recipient The target message receiver
    function sendETH(bytes32 recipient) external payable whenNotPaused {
        _sendMessage(recipient, recipient, new bytes(0));
    }

    /// @notice Send eth to calling contract to be withdrawn
    /// @param amount The amount of ETH to withdraw
    function withdrawETH(uint256 amount) external {
        require(
            msg.sender == address(MESSAGE_INBOX),
            "Only the Inbox can withdraw ETH"
        );
        payable(address(MESSAGE_INBOX)).transfer(amount);
    }

    /// @notice Calculates the serialization of the given message data
    /// @param sender The address sending the message
    /// @param recipient The receiving address
    /// @param owner The owner predicate required to play message
    /// @param nonce The outbox message nonce
    /// @param amount The value amount to send with message
    /// @param data The message data to be sent to the receiver
    /// @return bytes The serialized message data
    function serializeMessage(
        bytes32 sender,
        bytes32 recipient,
        bytes32 owner,
        uint64 nonce,
        uint64 amount,
        bytes memory data
    ) public pure returns (bytes memory) {
        return abi.encodePacked(sender, recipient, owner, nonce, amount, data);
    }

    /// @notice Calculates the messageID from the given message data
    /// @param sender The address sending the message
    /// @param recipient The receiving address
    /// @param owner The owner predicate required to play message
    /// @param nonce The outbox message nonce
    /// @param amount The value amount to send with message
    /// @param data The message data to be sent to the receiver
    /// @return messageId for the given message data
    function computeMessageId(
        bytes32 sender,
        bytes32 recipient,
        bytes32 owner,
        uint64 nonce,
        uint64 amount,
        bytes memory data
    ) public pure returns (bytes32) {
        return
            CryptographyLib.hash(
                serializeMessage(sender, recipient, owner, nonce, amount, data)
            );
    }

    /// @notice Gets the number of decimals used in the Fuel base asset
    /// @return decimals of the Fuel base asset
    function getFuelBaseAssetDecimals() public pure returns (uint8) {
        return uint8(FUEL_BASE_ASSET_DECIMALS);
    }

    ////////////////////////
    // Internal Functions //
    ////////////////////////

    /// @notice Performs all necessary logic to send a message to a target on Fuel
    /// @param recipient The receiving address
    /// @param owner The owner predicate required to play message
    /// @param data The message data to be sent to the receiver
    function _sendMessage(
        bytes32 recipient,
        bytes32 owner,
        bytes memory data
    ) private {
        bytes32 sender = bytes32(uint256(uint160(msg.sender)));
        unchecked {
            //make sure data size is not too large
            require(
                data.length < MAX_MESSAGE_DATA_SIZE,
                "message-data-too-large"
            );

            //make sure amount fits into the Fuel base asset decimal level
            uint256 precision = 10**(ETH_DECIMALS - FUEL_BASE_ASSET_DECIMALS);
            uint256 amount = msg.value / precision;
            if (msg.value > 0) {
                require(
                    amount * precision == msg.value,
                    "amount-precision-incompatability"
                );
                require(
                    amount <= ((2**64) - 1),
                    "amount-precision-incompatability"
                );
            }

            //emit message for Fuel clients to pickup (messageID calculated offchain)
            emit SentMessage(
                sender,
                recipient,
                owner,
                s_messageNonce,
                uint64(amount),
                data
            );

            //incriment nonce for next message
            ++s_messageNonce;
        }
    }

    /// @notice Default receive function
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {
        // handle incoming eth
    }
}
