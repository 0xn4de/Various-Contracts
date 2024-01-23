// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {FreeForAllToken} from "../../src/Jan04_FreeForAllToken.sol";
import "vyper/VyperDeployer.sol";


contract FreeForAllTokenTest is Test {
    FreeForAllToken public token;
    VyperDeployer vyperDeployer = new VyperDeployer();
    address alice;
    address bob;
    address charlie;
    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        token = FreeForAllToken(vyperDeployer.deployContract("Jan04_FreeForAllToken", abi.encode("FreeForAll Token", "FFA", 18, 1_000_000*1e18, bob))); //bob gets himself a million tokens
        vm.makePersistent(address(token));
    }

    function test_correctStartTime() public {
        assertEq(token.startTime(), block.timestamp + 1 days);
    }

    function test_ffaNotEnabledTransferRevert() public {
        vm.prank(alice);
        // Expect revert as FFA not enabled and alice isn't approved
        vm.expectRevert();
        token.transferFrom(bob, alice, 1); // 1 wei of token
    }
    function test_ffaEnabledTransfer() public {
        vm.warp(block.timestamp + 1 days + 1 seconds); // Go to where FFA is enabled
        vm.prank(alice);
        token.transferFrom(bob, alice, 1);
        assertEq(token.balanceOf(alice), 1); // Alice got herself a token
    }
    function test_ffaStartTimeChange() public {
        uint256 beforeStartTime = token.startTime();
        vm.warp(block.timestamp + 1 days + 1 hours + 1 seconds); // Go to where FFA is disabled
        // Make a legitimate transferFrom case
        vm.prank(bob);
        token.approve(alice, 1);
        vm.prank(alice);
        token.transferFrom(bob, alice, 1);
        assertEq(token.startTime(), beforeStartTime + 1 days);
    }
    // This test outlines how to get it on track if it has been more than 24 but less than 25 hours since last transferFrom
    // Similar way of getting it done if its over 25 hours, but needs more transferFroms
    function test_newFFAPeriodWithNoTransfers() public {
        uint256 beforeStartTime = token.startTime();
        vm.warp(block.timestamp + 2 days + 1 seconds); // Go to where FFA is enabled
        
        // Make a legitimate transferFrom case
        vm.prank(bob);
        token.approve(alice, 100);
        vm.prank(alice);
        // Even though it's FFA period right now (24h since last one), startTime is a day behind
        token.transferFrom(bob, alice, 1); // Sets startTime to right now - 1 second
        uint256 beforeStartTime2 = token.startTime();
        assertEq(beforeStartTime + 1 days, beforeStartTime2);
        token.transferFrom(alice, bob, 1); // Bob can take his token back because FFA is on
    }
}
