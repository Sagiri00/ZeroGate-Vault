// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IVerifier} from "src/IVerifier.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "lib/openzeppelin-contracts/lib/forge-std/src/interfaces/IERC4626.sol";

contract ZeroGateVault is ERC4626 {
    string public constant STATUS = "Ongoing";

    constructor(IERC20 asset_) ERC20("ZeroGate Vault", "ZGV") ERC4626(asset_) {}
}
