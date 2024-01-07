// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Jan07_Market.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract MarketTest is Test {
    address alice;
    address bob;
    MockERC20 token;
    MockERC20 token2;

    Market private market;

    function setUp() public {
        market = new Market();
        token = new MockERC20("TestToken", "TEST", 18);
        token2 = new MockERC20("TestToken2", "TEST2", 18);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        deal(address(token2), alice, 1000*1e18);
        deal(address(token), bob, 1000*1e18);
        vm.prank(bob);
        token.approve(address(market), type(uint256).max);
        vm.prank(alice);
        token2.approve(address(market), type(uint256).max);
    }

    function testCreateTrade() public {
        vm.prank(bob);
        // bob creates trade: 100 tokens for 50 token2s
        market.createTrade(address(token), 100*1e18, address(token2), 50*1e18, uint32(block.timestamp)+1);
    }
    function testCreateAndAcceptTradeTokenToToken() public {
        vm.prank(bob);
        // bob creates trade: 100 tokens for 50 token2s
        uint256 tradeId = market.createTrade(address(token), 100*1e18, address(token2), 50*1e18, uint32(block.timestamp)+1);
        
        assertEq(token2.balanceOf(alice), 1000*1e18);
        assertEq(token.balanceOf(alice), 0);
        
        vm.prank(alice);
        market.acceptTrade(tradeId);
        
        assertEq(token2.balanceOf(alice), 950*1e18);
        assertEq(token.balanceOf(alice), 100*1e18);
        assertEq(token2.balanceOf(bob), 50*1e18);
    }
    function testCreateAndAcceptTradeETHToETH() public {
        vm.prank(bob);
        // bob creates trade: 0.5 ETH for 0.45 ETH
        uint256 tradeId = market.createTrade{value: 0.5 ether}(address(0), 0.5 ether, address(0), 0.45 ether, uint32(block.timestamp)+1);
        
        assertEq(address(bob).balance, 0.5 ether);
        assertEq(address(alice).balance, 1 ether);
        
        vm.startPrank(alice);
        vm.expectRevert("No ETH sent");
        market.acceptTrade(tradeId);
        market.acceptTrade{value: 0.45 ether}(tradeId);
        vm.stopPrank();
        
        assertEq(address(bob).balance, 0.95 ether);
        assertEq(address(alice).balance, 1.05 ether);
    }
    function testCreateAndAcceptTradeETHToToken() public {
        vm.prank(bob);
        // bob creates trade: 0.5 ETH for 100 token2
        
        uint256 tradeId = market.createTrade{value: 0.5 ether}(address(0), 0.5 ether, address(token2), 100*1e18, uint32(block.timestamp)+1);
        assertEq(token2.balanceOf(alice), 1000*1e18);
        assertEq(token2.balanceOf(bob), 0);
        
        uint256 aliceEthBefore = alice.balance;
        
        vm.prank(alice);
        market.acceptTrade(tradeId);
        
        assertEq(token2.balanceOf(alice), 900*1e18);
        assertEq(token2.balanceOf(bob), 100*1e18);
        assertEq(alice.balance-aliceEthBefore, 0.5 ether); // gained .5 eth
    }
    function testCreateAndAcceptTradeTokenToEth() public {
        vm.prank(bob);
        // bob creates trade: 100 token to 0.5 ETH
        uint256 tradeId = market.createTrade(address(token), 100*1e18, address(0), 0.5 ether, uint32(block.timestamp)+1);
        
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1000*1e18);
        uint256 bobEthBefore = bob.balance;
        
        vm.prank(alice);
        market.acceptTrade{value:0.5 ether}(tradeId);
        
        assertEq(token.balanceOf(alice), 100*1e18);
        assertEq(token.balanceOf(bob), 900*1e18);
        assertEq(bob.balance-bobEthBefore, 0.5 ether); // gained .5 eth
    }
    function testCancelTradeETH() public {
        vm.startPrank(bob);
        // bob creates a trade: 0.5 ETH for 100 token2
        uint256 tradeId = market.createTrade{value: 0.5 ether}(address(0), 0.5 ether, address(token2), 100*1e18, uint32(block.timestamp)+1);
        assertEq(bob.balance, 0.5 ether);
        market.cancelTrade(tradeId);
        assertEq(bob.balance, 1 ether); // refund successful
        vm.stopPrank();
        // try to accept trade after cancel: expect revert
        vm.prank(alice);
        vm.expectRevert("Trade closed");
        market.acceptTrade(tradeId);
    }
    function testCancelTradeToken() public {
        vm.startPrank(bob);
        // bob creates a trade: 100 token for 0.5 ETH
        uint256 tradeId = market.createTrade(address(token), 100*1e18, address(0), 0.5 ether, uint32(block.timestamp)+1);
        market.cancelTrade(tradeId);
        vm.stopPrank();
        // try to accept trade after cancel: expect revert
        vm.prank(alice);
        vm.expectRevert("Trade closed");
        market.acceptTrade(tradeId);
    }
    function testCreateTradeRevertOnNoValue() public {
        vm.startPrank(bob);
        // Test Revert with no value sent
        vm.expectRevert("No ETH sent");
        market.createTrade(address(0), 0.5 ether, address(0), 0.45 ether, uint32(block.timestamp)+1);
        // bob creates trade: 0.5 ETH for 0.45 ETH, sends value
        uint256 tradeId = market.createTrade{value: 0.5 ether}(address(0), 0.5 ether, address(0), 0.45 ether, uint32(block.timestamp)+1);
        vm.stopPrank();
        
        assertEq(address(bob).balance, 0.5 ether);
        assertEq(address(alice).balance, 1 ether);
        
        vm.prank(alice);
        vm.expectRevert("No ETH sent"); // alice doesn't send value, expect revert
        market.acceptTrade(tradeId);
    }
    function testCancelTradeRevertOnWrongCreator() public {
        vm.prank(bob);
        // bob creates a trade: 100 token for 0.5 ETH
        uint256 tradeId = market.createTrade(address(token), 100*1e18, address(0), 0.5 ether, uint32(block.timestamp)+1);
        // try to cancel as Alice
        vm.prank(alice);
        vm.expectRevert("You are not the creator of the trade");
        market.cancelTrade(tradeId);
    }
    function testCancelTradeRevertOnClosure() public {
        vm.prank(bob);
        // bob creates trade: 0.5 ETH for 0.45 ETH
        uint256 tradeId = market.createTrade{value: 0.5 ether}(address(0), 0.5 ether, address(0), 0.45 ether, uint32(block.timestamp)+1);
        vm.prank(alice);
        // alice accepts
        market.acceptTrade{value: 0.45 ether}(tradeId);
        vm.prank(bob);
        vm.expectRevert("Trade closed");
        market.cancelTrade(tradeId);
    }
}