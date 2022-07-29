// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {FuelMessageOutbox} from "./FuelMessageOutbox.sol";
import {CryptographyLib} from "../lib/Cryptography.sol";
import {BinaryMerkleTree} from "../lib/tree/binary/BinaryMerkleTree.sol";
import {ExcessivelySafeCall} from "../vendor/ExcessivelySafeCall.sol";
import {
    IFuelMessageInbox,
    OutputMessageProof
} from "../messaging/IFuelMessageInbox.sol";

/// @title FuelMessageInbox
/// @notice The Fuel Message Inbox contract relays messages sent from Fuel
/// @dev This contract is to be deployed alongside FuelMessageOutbox
contract FuelMessageInbox is
    IFuelMessageInbox,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    ///////////////
    // Constants //
    ///////////////

    /// @dev The number of decimals that the base Fuel asset uses
    uint256 public constant FUEL_BASE_ASSET_DECIMALS = 9;
    uint256 public constant ETH_DECIMALS = 18;

    /// @dev Non-zero null value to optimize gas costs
    bytes32 internal constant NULL_MESSAGE_SENDER =
        0x000000000000000000000000000000000000000000000000000000000000dead;

    /// @dev Address of the MessageOutbox
    FuelMessageOutbox public immutable MESSAGE_OUTBOX;

    /////////////
    // Storage //
    /////////////

    /// @notice Current message sender for other contracts to reference
    bytes32 internal s_currentMessageSender;

    /// @notice The address allowed to commit new messageRoot states
    address internal s_messageRootCommitter;

    /// @notice The waiting period for messageRoot states (in milliseconds)
    uint64 internal s_messageRootTimelock;

    /// @notice The message output roots mapped to the timestamp they were comitted
    mapping(bytes32 => uint256) public s_messageRoots;

    /// @notice Mapping of message hash to boolean success value
    mapping(bytes32 => bool) public s_successfulMessages;

    /////////////////
    // Constructor //
    /////////////////

    /// @notice Contract constructor to setup immutable values
    /// @param messageOutbox Address of the FuelMessageOutbox contract
    constructor(FuelMessageOutbox messageOutbox) Ownable() {
        MESSAGE_OUTBOX = messageOutbox;
        s_currentMessageSender = NULL_MESSAGE_SENDER;
        s_messageRootCommitter = msg.sender;
        s_messageRootTimelock = 0;
    }

    //////////////////////
    // Public Functions //
    //////////////////////

    /// @notice Pause incoming messages
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause incoming messages
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets the address of the EOA or contract allowed to commit new messageRoot states
    /// @param messageRootCommitter Address of the EOA or contract allowed to commit new messageRoot states
    function setMessageRootCommitter(address messageRootCommitter)
        external
        onlyOwner
    {
        s_messageRootCommitter = messageRootCommitter;
    }

    /// @notice Sets the waiting period for messageRoot states
    /// @param messageRootTimelock The waiting period for messageRoot states (in milliseconds)
    function setMessageRootTimelock(uint64 messageRootTimelock)
        external
        onlyOwner
    {
        s_messageRootTimelock = messageRootTimelock;
    }

    /// @notice Used by message receiving contracts to get the address on Fuel that sent the message
    function getMessageSender() external view returns (bytes32) {
        require(
            s_currentMessageSender != NULL_MESSAGE_SENDER,
            "Current message sender not set"
        );
        return s_currentMessageSender;
    }

    /// @notice Relays a message published on Fuel
    /// @param sender The address sending the message
    /// @param recipient The receiving address
    /// @param amount The value amount to send with message
    /// @param nonce The inbox message nonce
    /// @param data The ABI of the call to make to the receiver
    /// @param merkleProof Merkle proof to prove this message is valid
    /// @dev Made payable to reduce gas costs
    function relayMessage(
        bytes32 sender,
        bytes32 recipient,
        bytes32 nonce,
        uint64 amount,
        bytes calldata data,
        OutputMessageProof calldata merkleProof
    ) external payable nonReentrant whenNotPaused {
        //calculate message ID and amount sent
        bytes32 messageId =
            computeMessageId(sender, recipient, nonce, amount, data);
        uint256 messageValue =
            amount * (10**(ETH_DECIMALS - FUEL_BASE_ASSET_DECIMALS));

        //verify the merkle proof root
        uint256 messageRootTimestamp = s_messageRoots[merkleProof.root];
        require(messageRootTimestamp > 0, "Invalid root");
        // solhint-disable-next-line not-rely-on-time
        require(
            messageRootTimestamp < block.timestamp - s_messageRootTimelock,
            "Root timelocked"
        );

        //verify merkle inclusion proof
        bool messageExists =
            BinaryMerkleTree.verify(
                merkleProof.root,
                abi.encodePacked(messageId),
                merkleProof.proof,
                merkleProof.key,
                merkleProof.numLeaves
            );
        require(messageExists, "Invalid proof");

        //verify message has not already been successfully relayed
        require(!s_successfulMessages[messageId], "Message already relayed");

        //make sure we have enough gas to finish after function
        //TODO: revisit these values
        require(gasleft() >= 45000, "Insufficient gas for relay");

        //set message sender for receiving contract to reference
        s_currentMessageSender = sender;

        //move ETH from the outbox so we can send it in function call
        if (messageValue > 0) {
            MESSAGE_OUTBOX.withdrawETH(messageValue);
        }

        //relay message
        (bool success, ) =
            ExcessivelySafeCall.excessivelySafeCall(
                address(uint160(uint256(recipient))),
                gasleft() - 40000,
                messageValue,
                0,
                data
            );

        //make sure relay succeeded
        require(success, "Message relay failed");

        //unset message sender reference
        s_currentMessageSender = NULL_MESSAGE_SENDER;

        //keep track of successfully relayed messages
        s_successfulMessages[messageId] = true;
        emit RelayedMessage(messageId);
    }

    /// @notice Commits a new message output root
    /// @param messageRoot The message root to commit
    function commitMessageRoot(bytes32 messageRoot) external {
        require(s_messageRootCommitter == msg.sender, "Caller not committer");
        if (s_messageRoots[messageRoot] == uint256(0)) {
            // solhint-disable-next-line not-rely-on-time
            s_messageRoots[messageRoot] = block.timestamp;
        }
    }

    /// @notice Calculates the serialization of the given message data
    /// @param sender The address sending the message
    /// @param recipient The receiving address
    /// @param nonce The outbox message nonce
    /// @param amount The value amount to send with message
    /// @param data The message data to be sent to the receiver
    /// @return bytes The serialized message data
    function serializeMessage(
        bytes32 sender,
        bytes32 recipient,
        bytes32 nonce,
        uint64 amount,
        bytes calldata data
    ) public pure returns (bytes memory) {
        return abi.encodePacked(sender, recipient, nonce, amount, data);
    }

    /// @notice Calculates the messageID from the given message data
    /// @param sender The address sending the message
    /// @param recipient The receiving address
    /// @param nonce The outbox message nonce
    /// @param amount The value amount to send with message
    /// @param data The message data to be sent to the receiver
    /// @return messageId for the given message data
    function computeMessageId(
        bytes32 sender,
        bytes32 recipient,
        bytes32 nonce,
        uint64 amount,
        bytes calldata data
    ) public pure returns (bytes32) {
        return
            CryptographyLib.hash(
                serializeMessage(sender, recipient, nonce, amount, data)
            );
    }

    /// @notice Gets the number of decimals used in the Fuel base asset
    /// @return decimals of the Fuel base asset
    function getFuelBaseAssetDecimals() public pure returns (uint8) {
        return uint8(FUEL_BASE_ASSET_DECIMALS);
    }

    /// @notice Default receive for receiving eth from the outbox contract
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {
        // handle incoming eth
    }
}
