// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Jan05_FreeForAll1155.sol";

contract FreeForAll1155Test is Test {
    using stdStorage for StdStorage;
    address alice;
    address bob;

    FreeForAll1155 private nft;

    function setUp() public {
        // Deploy NFT contract
        nft = new FreeForAll1155();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function test_correctStartTime() public {
        assertEq(nft.startTime(), block.timestamp + 1 days);
    }

    function test_ffaNotEnabledTransferRevert() public {
        nft.mintTo(address(bob), 0);
        vm.prank(alice);
        // Expect revert as FFA not enabled and alice isn't approved
        vm.expectRevert("NOT_AUTHORIZED");
        nft.safeTransferFrom(bob, alice, 0, 1, "");
    }
    function test_ffaEnabledTransfer() public {
        nft.mintTo(address(bob), 0);
        vm.warp(block.timestamp + 1 days + 1 seconds); // Go to where FFA is enabled
        vm.prank(alice);
        nft.safeTransferFrom(bob, alice, 0, 1, "");
        assertEq(nft.balanceOf(alice, 0), 1);
    }
    function test_ffaStartTimeChange() public {
        uint256 beforeStartTime = nft.startTime();
        nft.mintTo(address(bob), 0);
        vm.warp(block.timestamp + 1 days + 1 hours + 1 seconds); // Go to where FFA is disabled
        vm.prank(bob);
        nft.safeTransferFrom(bob, alice, 0, 1, "");
        assertEq(nft.startTime(), beforeStartTime + 1 days);
    }

    // This test outlines how to get it on track if it has been more than 24 but less than 25 hours since last transferFrom
    // Similar way of getting it done if its over 25 hours, but needs more transferFroms
    function test_newFFAPeriodWithNoTransfers() public {
        uint256 beforeStartTime = nft.startTime();
        nft.mintTo(address(bob), 0);
        vm.warp(block.timestamp + 2 days + 1 seconds); // Go to where FFA is enabled
        vm.prank(bob);
        // Even though it's FFA period right now (24h since last one), startTime is a day behind
        nft.safeTransferFrom(bob, alice, 0, 1, ""); // Sets startTime to right now - 1 second
        uint256 beforeStartTime2 = nft.startTime();
        assertEq(beforeStartTime + 1 days, beforeStartTime2);
        nft.safeTransferFrom(alice, bob, 0, 1, ""); // Bob can take his nft back because FFA is on
    }
    function test_maxSupplyRevert() public {
        for (uint256 i = 0; i < 100; i++) {
            nft.mintTo(address(bob), 0);
        }
        vm.expectRevert("No supply available");
        nft.mintTo(address(bob), 0);
    }
    function test_wrongIdRevert() public {
        vm.expectRevert("ID does not exist");
        nft.mintTo(address(bob), 125995195);
    }
}