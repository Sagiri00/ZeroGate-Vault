// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IVerifier
/// @notice Minimal interface for a ZK proof verifier
interface IVerifier {
    /// @notice Verifies a zero-knowledge proof against its public inputs
    /// @param proof The serialized ZK proof bytes
    /// @param publicInputs The public inputs the proof was generated against
    /// @return True if the proof is valid, false otherwise
    function verify(bytes calldata proof, bytes32[] calldata publicInputs) external view returns (bool);
}

