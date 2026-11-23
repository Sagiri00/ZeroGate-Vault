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
    uint256 constant balanceOfBob = 1000;

    /// @dev Common variables for testing

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    uint256 amount = 100;

    function setUp() public {
        token = new MockERC20();
        verifier = new MockVerifier(true);
        vault = new ZeroGateVault(token, verifier);
        token.mint(alice, balanceOfAlice);
        token.mint(bob, balanceOfBob);
    }

    /// Helper Function
    function _inputsFor(
        address user
    ) internal pure returns (bytes32[] memory inputs) {
        inputs = new bytes32[](1);
        inputs[0] = bytes32(uint256(uint160(user)));
    }

    /// Testing Area
    function testDepositWithValidProof() public {
        _inputsFor(alice);

        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.depositWithProof(amount, alice, "", _inputsFor(alice));
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 100);
        assertEq(token.balanceOf(address(vault)), 100);
        assertEq(token.balanceOf(alice), balanceOfAlice - amount);
        assertTrue(vault.isVerified(alice));
    }

    function testDepositWithInvalidProof() public {
        _inputsFor(alice);

        verifier.setShouldPass(false);
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vm.expectRevert(ZeroGateVault.ZGV_ProofDenied.selector);
        vault.depositWithProof(amount, alice, "", _inputsFor(alice));
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(alice), balanceOfAlice);
        assertFalse(vault.isVerified(alice));
    }

    function testPlainDepositIsDisabled() public {
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

    function testDepositWithWrongReceiverRevert() public {
        bytes memory proof = "";
        bytes32[] memory publicInputs = new bytes32[](1);
        publicInputs[0]; /* Bob's address in bytes32 form */

        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vm.expectRevert(ZeroGateVault.ZGV_InvalidPublicInputs.selector);
        vault.depositWithProof(amount, alice, proof, publicInputs);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(vault)), 0);
        assertFalse(vault.isVerified(alice));
    }

    function testDepositWithEmptyPublicInputsRevert() public {
        bytes memory proof = "";
        bytes32[] memory publicInputs = new bytes32[](0);

        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vm.expectRevert(ZeroGateVault.ZGV_InvalidPublicInputs.selector);
        vault.depositWithProof(amount, alice, proof, publicInputs);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(vault)), 0);
        assertFalse(vault.isVerified(alice));
    }

    function testTransferToUnverifiedRevert() public {
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.depositWithProof(amount, alice, "", _inputsFor(alice));
        vm.expectRevert(ZeroGateVault.ZGV_RecipientNotVerified.selector);
        vault.transfer(bob, 50);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 100);
        assertEq(token.balanceOf(address(vault)), 100);
        assertEq(vault.balanceOf(bob), 0);
    }

    function testTransferToVerified() public {
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.depositWithProof(amount, alice, "", _inputsFor(alice));
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(vault), amount);
        vault.depositWithProof(amount, bob, "", _inputsFor(bob));
        vm.stopPrank();

        vm.prank(alice);
        vault.transfer(bob, 50);

        assertTrue(vault.isVerified(alice));
        assertEq(vault.balanceOf(alice), 50);
        assertEq(token.balanceOf(alice), (balanceOfAlice - 100));

        assertTrue(vault.isVerified(bob));
        assertEq(vault.balanceOf(bob), amount + 50);
        assertEq(token.balanceOf(bob), (balanceOfBob - 100));
    }

    function testWithdrawFunction() public {
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.depositWithProof(amount, alice, "", _inputsFor(alice));
        vm.stopPrank();

        assertTrue(vault.isVerified(alice));
        assertEq(vault.balanceOf(alice), 100);
        assertEq(token.balanceOf(alice), (balanceOfAlice - 100));

        vm.prank(alice);
        vault.withdraw(amount, alice, alice);

        assertEq(token.balanceOf(alice), balanceOfAlice);
        assertEq(vault.balanceOf(address(vault)), 0);
    }

    function testRedeemAfterDeposit() public {
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.depositWithProof(amount, alice, "", _inputsFor(alice));
        vm.stopPrank();

        assertTrue(vault.isVerified(alice));
        assertEq(vault.balanceOf(alice), 100);
        assertEq(token.balanceOf(alice), (balanceOfAlice - 100));

        vm.prank(alice);
        vault.redeem(amount, alice, alice);

        assertEq(token.balanceOf(alice), balanceOfAlice);
    }

    function testFuzzDeposit(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, 1000);
        // _depositAs(alice, _amount);
        vm.startPrank(alice);
        token.approve(address(vault), depositAmount);
        vault.depositWithProof(depositAmount, alice, "", _inputsFor(alice));
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), depositAmount);
        assertEq(token.balanceOf(address(vault)), depositAmount);
    }
}
