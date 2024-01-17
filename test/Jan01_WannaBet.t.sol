// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {WannaBet, Side} from "../src/Jan01_WannaBet.sol";
contract WannaBetTest is Test {
    WannaBet public betContract;
    address alice;
    address bob;
    address charlie;
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), 18800000); // ETH Price 2254.51
        betContract = new WannaBet(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }
    function test_wagerCreateReverts() public {
        vm.prank(bob);
        // Bob tries to bet that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        // Doesn't send value, expect revert in value check
        vm.expectRevert("No ETH Bet");
        betContract.createBet(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);

        // Accidentally sets the timestamp to not be in the future, expect it to revert
        vm.expectRevert("Bet end is in the past");
        betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp, block.timestamp + 2 days, 1 ether);
        
        // Accidentally sets the taker accept deadline timestamp to not be in the future, expect it to revert
        vm.expectRevert("Taker deadline cannot be in the past nor after settling timestamp");
        betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp, 1 ether);
        
        // Accidentally sets the taker accept deadline timestamp to be after the settling timestamp (allows you to game his bet and wait for the last moment)
        vm.expectRevert("Taker deadline cannot be in the past nor after settling timestamp");
        betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 6 days, 1 ether);
    }
    function test_wagerAcceptReverts() public {
        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);

        vm.prank(alice);
        // Alice tries to accept bet with .5 ETH when bob set the counterparty at 1 ETH, expect revert
        vm.expectRevert("You bet too little/too much");
        betContract.acceptBet{value: 0.5 ether}(betId);

        vm.warp(block.timestamp + 2.01 days); // Jump forward 2 days to after accept expiry


        vm.expectRevert("Too late, bet closed");
        betContract.acceptBet{value: 1 ether}(betId);
        
        vm.warp(block.timestamp - 2.01 days); 
        vm.prank(charlie);
        // Charlie accepts the bet first instead, with the correct amount and time
        betContract.acceptBet{value: 1 ether}(betId);
        vm.prank(alice);

        // Alice sends the right amount this time, but is too late, expect revert
        vm.expectRevert("Someone already bet");
        betContract.acceptBet{value: 1 ether}(betId);
        
    }
    function test_Wager() public {
        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);
        vm.stopPrank();

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId); // Alice accepts the bet
        vm.rollFork(18850000); // ETH Price 2292.91807
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling

        assertEq(address(bob).balance, 11 ether);
    }
    function test_WagerLoss() public {

        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.UNDER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId);
        vm.rollFork(18850000); // ETH Price 2292.91807
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling

        assertEq(address(bob).balance, 9 ether);
        assertEq(address(alice).balance, 11 ether);
    }
    function test_WagerLoss2() public {

        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2400 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2400*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId);
        vm.rollFork(18841000); // ETH Price 2303.7560007
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling

        assertEq(address(bob).balance, 9 ether);
        assertEq(address(alice).balance, 11 ether);
    }

    function test_createAndClose() public {
        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days, settles in 5 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);
        vm.warp(block.timestamp + 2.01 days);
        assertEq(address(bob).balance, 9 ether);
        betContract.closeBet(betId);
        assertEq(address(bob).balance, 10 ether); // Funds get returned

        // Closing again reverts since bet closed
        vm.expectRevert("Bet closed/settled");
        betContract.closeBet(betId);
    }
    function test_createAndCloseRevert() public {
        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days, settles in 5 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, block.timestamp + 5 days, block.timestamp + 2 days, 1 ether);

        // Accept bet as alice
        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId);

        // Try to close bet, it's been accepted but timestamp check is first
        vm.expectRevert("Too early");
        betContract.closeBet(betId);

        vm.warp(block.timestamp + 2.01 days); // Jump to bet accept expiry
        
        // Try to close bet, timestamp fits but bet was accepted
        vm.expectRevert("Bet already accepted");
        betContract.closeBet(betId);
        assertEq(address(bob).balance, 9 ether); // Funds don't get returned
    }
    function test_getChainlinkPrice() public {
        int256 price = betContract.getPrice();
        assertEq(price, 2254.51*1e8); // Price at fork block (18800000)
    }
}
