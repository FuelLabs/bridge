// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

struct MerkleBranch {
    bytes32[] proof;
    bytes32 key;
    bytes value;
}
