// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import {SparseCompactMerkleProof} from "./Proofs.sol";

struct MerkleBranch {
    SparseCompactMerkleProof proof;
    bytes32 key;
    bytes value;
}
