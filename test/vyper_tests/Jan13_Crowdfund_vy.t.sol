// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Crowdfund} from "../../src/Jan13_Crowdfund.sol";
import "vyper/VyperDeployer.sol";

contract CrowdfundTest is Test {
    address alice;
    address bob;
    address charlie;
    
    VyperDeployer vyperDeployer = new VyperDeployer();
    Crowdfund private crowdfund;

    function setUp() public {
        crowdfund = Crowdfund(vyperDeployer.deployContract("Jan13_Crowdfund"));

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }

    function testRaise() public {
        uint256 raiseId = crowdfund.createRaise(15 ether, 1 weeks, bob);
        vm.prank(alice);
        crowdfund.contribute{value: 6 ether}(raiseId);
        vm.prank(charlie);
        crowdfund.contribute{value: 9 ether}(raiseId);

        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        vm.prank(bob);
        crowdfund.withdraw(raiseId);
        assertEq(bob.balance, 115 ether);
    }
    function testRaiseDoesntMeetGoal() public {
        uint256 raiseId = crowdfund.createRaise(15 ether, 1 weeks, bob);
        vm.prank(alice);
        crowdfund.contribute{value: 6 ether}(raiseId);
        vm.prank(charlie);
        crowdfund.contribute{value: 8 ether}(raiseId);

        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        vm.prank(bob);
        vm.expectRevert("Raise did not meet its goal");
        crowdfund.withdraw(raiseId);
        vm.prank(alice);
        crowdfund.withdrawContribution(raiseId);
        vm.prank(charlie);
        crowdfund.withdrawContribution(raiseId);
        assertEq(alice.balance, 100 ether);
        assertEq(bob.balance, 100 ether);
        assertEq(charlie.balance, 100 ether);
    }
    function testCreateRaiseReverts() public {
        vm.expectRevert("Wrong inputs");
        crowdfund.createRaise(0, 1 weeks, bob);
        vm.expectRevert("Wrong inputs");
        crowdfund.createRaise(1 ether, 0, bob);
    }
    function testContributeReverts() public {
        uint256 raiseId = crowdfund.createRaise(15 ether, 1 weeks, bob);
        vm.startPrank(alice);

        vm.expectRevert("Raise does not exist");
        crowdfund.contribute{value: 6 ether}(11111);

        vm.expectRevert("Raise over goal");
        crowdfund.contribute{value: 20 ether}(raiseId);

        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        vm.expectRevert("Raise over");
        crowdfund.contribute{value: 6 ether}(raiseId);
        vm.stopPrank();
    }
    function testWithdrawReverts() public {
        uint256 raiseId = crowdfund.createRaise(15 ether, 1 weeks, bob);
        vm.prank(alice);
        crowdfund.contribute{value: 6 ether}(raiseId);
        vm.prank(charlie);
        crowdfund.contribute{value: 9 ether}(raiseId);

        
        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        vm.prank(alice);
        vm.expectRevert("Not raise owner");
        crowdfund.withdraw(raiseId);
        
        vm.startPrank(bob);
        crowdfund.withdraw(raiseId);
        vm.expectRevert("Raise finished");
        crowdfund.withdraw(raiseId);
        vm.stopPrank();

        uint256 raiseId2 = crowdfund.createRaise(15 ether, 1 weeks, bob);

        vm.prank(alice);
        crowdfund.contribute{value: 6 ether}(raiseId2);

        vm.prank(charlie);
        crowdfund.contribute{value: 8 ether}(raiseId2);

        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        vm.prank(bob);
        vm.expectRevert("Raise did not meet its goal");
        crowdfund.withdraw(raiseId2);
    }
    function testWithdrawContributionReverts() public {
        uint256 raiseId = crowdfund.createRaise(15 ether, 1 weeks, bob);
        vm.prank(alice);
        crowdfund.contribute{value: 6 ether}(raiseId);
        vm.prank(charlie);
        crowdfund.contribute{value: 9 ether}(raiseId);

        vm.prank(alice);
        vm.expectRevert("Raise not over");
        crowdfund.withdrawContribution(raiseId);

        vm.warp(block.timestamp + 1 weeks + 1 seconds);
        vm.prank(alice);
        vm.expectRevert("Raise met its goal");
        crowdfund.withdrawContribution(raiseId);

        uint256 raiseId2 = crowdfund.createRaise(15 ether, 1 weeks, bob);
        vm.prank(alice);
        crowdfund.contribute{value: 6 ether}(raiseId2);
        vm.prank(charlie);
        crowdfund.contribute{value: 8 ether}(raiseId2);

        vm.warp(block.timestamp + 1 weeks + 1 seconds);

        vm.prank(bob);
        vm.expectRevert("Nothing to withdraw");
        crowdfund.withdrawContribution(raiseId2);
    }
}