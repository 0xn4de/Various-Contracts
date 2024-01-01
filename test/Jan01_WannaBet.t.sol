// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {WannaBet, Side, BetData, AggregatorV3Interface} from "../src/Jan01_WannaBet.sol";
contract WannaBetTest is Test {
    WannaBet public betContract;
    AggregatorV3Interface priceFeed;
    address alice;
    address bob;
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), 18800000); // ETH Price 2254.51
        betContract = new WannaBet(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }
    function test_Wager() public {

        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);
        vm.stopPrank();

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId);
        vm.rollFork(18850000); // ETH Price 2292.91807
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling (TODO)

        assertEq(address(bob).balance, 11 ether);
    }
    function test_WagerLoss() public {
        // (,int price,,,) = priceFeed.latestRoundData();

        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.UNDER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId);
        vm.rollFork(18850000); // ETH Price 2292.91807
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling (TODO)

        assertEq(address(bob).balance, 9 ether);
        assertEq(address(alice).balance, 11 ether);
    }

    function test_createAndClose() public {
        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);
        vm.warp(block.timestamp + 2.01 days);
        betContract.closeBet(betId);
        assertEq(address(bob).balance, 10 ether); // Funds get returned
    }
    function test_createAndCloseRevert() public {
        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId);
        vm.warp(block.timestamp + 2.01 days);
        vm.expectRevert("Bet already accepted");

        betContract.closeBet(betId);
        assertEq(address(bob).balance, 9 ether); // Funds don't get returned
    }
}
