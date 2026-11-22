// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {MockERC20} from "test/Mocks/MockERC20.t.sol";
import {MockVerifier} from "src/MockVerifier.sol";
import {ZeroGateVault} from "src/ZeroGateVault.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";

contract ZeroGateVaultTTest is Test {
    MockERC20 token;
    MockVerifier verifier;
    ZeroGateVault vault;
    uint256 constant balanceOfAlice = 1000;

    address alice = makeAddr("Alice");

    function setUp() public {
        token = new MockERC20();
        verifier = new MockVerifier(true);
        vault = new ZeroGateVault(token, verifier);
        token.mint(alice, balanceOfAlice);
    }

    function testDepositWithValidProof() public {
        uint256 amount = 100;

        bytes memory proof = "";
        bytes32[] memory publicInputs = new bytes32[](1);
        publicInputs[0] = bytes32(uint256(uint160(alice)));

        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.depositWithProof(amount, alice, proof, publicInputs);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 100);
        assertEq(token.balanceOf(address(vault)), 100);
        assertEq(token.balanceOf(alice), balanceOfAlice - amount);
        assertTrue(vault.isVerified(alice));
    }

    function testDepositWithInvalidProof() public {
        uint256 amount = 100;

        bytes memory proof = "";
        bytes32[] memory publicInputs = new bytes32[](1);
        publicInputs[0] = bytes32(uint256(uint160(alice)));

        verifier.setShouldPass(false);
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vm.expectRevert(ZeroGateVault.ZGV_ProofDenied.selector);
        vault.depositWithProof(amount, alice, proof, publicInputs);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(alice), balanceOfAlice);
        assertFalse(vault.isVerified(alice));
    }

    function testPlainDepositIsDisabled() public {
        uint256 amount = 100;

        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vm.expectRevert(ZeroGateVault.ZGV_DepositDisabled.selector);
        vault.deposit(amount, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(alice), balanceOfAlice);
        assertFalse(vault.isVerified(alice));
    }

    function testPlainMintIsDisabled() public {
        uint256 amount = 100;

        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vm.expectRevert(ZeroGateVault.ZGV_MintDisabled.selector);
        vault.mint(amount, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(alice), balanceOfAlice);
        assertFalse(vault.isVerified(alice));

    }
}
