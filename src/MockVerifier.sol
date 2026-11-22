// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IVerifier} from "../src/IVerifier.sol";

contract MockVerifier is IVerifier {
    bool public shouldPass;

    constructor(bool shouldPass_) {
        shouldPass = shouldPass_;
        shouldPass_ = false;
    }

    function setShouldPass(bool value) external {
        shouldPass = value;
    }

    function verify(bytes calldata, bytes32[] calldata) external view override returns (bool) {
        return shouldPass;
    }
}
