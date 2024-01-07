// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MockERC1155} from "solmate/test/utils/mocks/MockERC1155.sol";
import "forge-std/Test.sol";
import {MockERC1155Vault} from "./mocks/MockERC1155Vault.sol";

contract ERC1155VaultTest is Test {
    MockERC1155 underlying;
    MockERC1155 underlying2;
    MockERC1155 underlying3;
    MockERC1155Vault vault;
    address alice;
    address bob;
    address charlie;

    function setUp() public {
        underlying = new MockERC1155();
        underlying2 = new MockERC1155();
        underlying3 = new MockERC1155();
        vault = new MockERC1155Vault();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        vault.create(underlying, 1);
        vault.create(underlying2, 1);
        vault.create(underlying3, 1);
        vault.create(underlying3, 2); // create two vaults with underlying3, one for tokenId 1 and one for 2
    }
    function testDepositToVault() public {
        // mint bob 5 erc1155s with tokenId 1
        underlying.mint(bob, 1, 5, "");
        vm.startPrank(bob);
        underlying.setApprovalForAll(address(vault), true);
        vault.deposit(underlying, 1, 5, bob);
        vm.stopPrank();
        assertEq(vault.balanceOf(bob, 1), 5);
    }
    function testMintFromVault() public {
        // mint bob 5 erc1155s with tokenId 1
        underlying.mint(bob, 1, 5, "");
        vm.startPrank(bob);
        underlying.setApprovalForAll(address(vault), true);
        vault.mint(underlying, 1, 5, bob);
        vm.stopPrank();
        assertEq(vault.balanceOf(bob, 1), 5); // Check bob's balance for vault #1 tokens
    }
    function testWithdrawFromVault() public {
        // mint bob 5 erc1155s with tokenId 1
        underlying.mint(bob, 1, 5, "");
        vm.startPrank(bob);
        underlying.setApprovalForAll(address(vault), true);
        vault.mint(underlying, 1, 5, bob);
        assertEq(vault.balanceOf(bob, 1), 5);
        // withdraw his tokens back
        vault.withdraw(underlying, 1, 5, bob, bob, "");
        assertEq(underlying.balanceOf(bob, 1), 5); // check that bob got his tokens back
    }
    function testRedeemFromVault() public {
        // mint bob 5 erc1155s with tokenId 1
        underlying.mint(bob, 1, 5, "");
        vm.startPrank(bob);
        underlying.setApprovalForAll(address(vault), true);
        vault.mint(underlying, 1, 5, bob);
        assertEq(vault.balanceOf(bob, 1), 5);
        // withdraw his tokens back
        vault.redeem(underlying, 1, 5, bob, bob, ""); 
        assertEq(underlying.balanceOf(bob, 1), 5); // check that bob got his tokens back
    }
    function testDepositAndWithdrawForMultipleVaults() public {
        underlying.mint(bob, 1, 5, "");
        underlying2.mint(bob, 1, 4, "");
        underlying3.mint(bob, 1, 3, "");
        underlying3.mint(bob, 2, 10, "");
        vm.startPrank(bob);
        underlying.setApprovalForAll(address(vault), true);
        underlying2.setApprovalForAll(address(vault), true);
        underlying3.setApprovalForAll(address(vault), true);
        vault.mint(underlying, 1, 5, bob);
        vault.mint(underlying2, 1, 4, bob);
        vault.mint(underlying3, 1, 3, bob);
        vault.mint(underlying3, 2, 10, bob);
        assertEq(underlying.balanceOf(bob, 1), 0); // check that something did go out
        // check that bob got his various ERC1155 tokens with different tokenIds
        assertEq(vault.balanceOf(bob, 1), 5);
        assertEq(vault.balanceOf(bob, 2), 4);
        assertEq(vault.balanceOf(bob, 3), 3);
        assertEq(vault.balanceOf(bob, 4), 10);
        // start withdrawing, 2 redeems 2 withdraws for good measure
        vault.redeem(underlying, 1, 5, bob, bob, ""); 
        vault.withdraw(underlying2, 1, 4, bob, bob, ""); 
        vault.redeem(underlying3, 1, 3, bob, bob, ""); 
        vault.withdraw(underlying3, 2, 10, bob, bob, ""); 
        assertEq(underlying.balanceOf(bob, 1), 5);
        assertEq(underlying2.balanceOf(bob, 1), 4);
        assertEq(underlying3.balanceOf(bob, 1), 3);
        assertEq(underlying3.balanceOf(bob, 2), 10);
    }
    function testRedeemFromVaultWithMultiplePeople() public {
        // mint bob and alice 5 erc1155s with tokenId 1
        underlying.mint(bob, 1, 5, "");
        underlying.mint(alice, 1, 5, "");
        vm.startPrank(bob);
        underlying.setApprovalForAll(address(vault), true);
        vault.mint(underlying, 1, 5, bob);
        assertEq(vault.balanceOf(bob, 1), 5);
        vm.stopPrank();
        vm.startPrank(alice);
        underlying.setApprovalForAll(address(vault), true);
        vault.mint(underlying, 1, 5, alice);
        vm.stopPrank();
        vm.startPrank(bob);
        // withdraw his tokens back
        vault.redeem(underlying, 1, 5, bob, bob, ""); 
        assertEq(underlying.balanceOf(bob, 1), 5); // check that bob got his tokens back
        vm.stopPrank();
        vm.startPrank(alice);
        vault.balanceOf(alice, 1);
        vault.redeem(underlying, 1, 5, alice, alice, ""); 
        assertEq(underlying.balanceOf(alice, 1), 5); // check that alice got her tokens back
    }

}