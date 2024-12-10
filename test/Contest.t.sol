// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {Contest} from "../src/Contest.sol";
contract ContestTest is Test {
    address alice;
    address bob;
    address charlie;
    Contest contest;
    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        contest = new Contest(uint32(block.timestamp), 100, 0.1 ether);
        deal(alice, 1 ether);
        deal(bob, 1 ether);
        vm.makePersistent(address(contest), alice, bob);
    }

    function test_Contest() public {
        vm.prank(alice);
        contest.bid{value: 0.1 ether}();

        assertEq(contest.lastCallBlock(), block.number);
        assertEq(contest.lastCaller(), alice);

        vm.prank(bob);
        contest.bid{value: 0.1 ether}();
        vm.roll(block.number+5);

        vm.prank(alice);
        contest.bid{value: 0.1 ether}();

        assertEq(contest.lastCallBlock(), block.number);
        assertEq(contest.lastCaller(), alice);

        vm.prank(bob);
        contest.bid{value: 0.1 ether}();

        vm.roll(block.number+100);

        vm.prank(bob);
        contest.end();
        assertEq(bob.balance, 1.2 ether);
    }

    function test_ContestReverts() public {
        // so we can deal with timestamps easily
        contest = new Contest(uint32(block.timestamp+1), 100, 0.1 ether);

        vm.startPrank(bob);

        // test revert when contest hasn't started
        vm.warp(block.timestamp-1); // go to before startTime
        vm.expectRevert("Hasn't started");
        contest.bid{value: 0.1 ether}();

        // test revert when bid is less than minimum
        vm.warp(block.timestamp+2); // go back to startTime
        vm.expectRevert("Bid more");
        contest.bid{value: 0.09 ether}();

        // test revert when blocks haven't been waited
        vm.expectRevert("Wait a little more");
        contest.end();

        // test revert where nobody has bid
        vm.roll(block.number+100);
        vm.expectRevert("You have to bid first");
        contest.end();
    }

}
