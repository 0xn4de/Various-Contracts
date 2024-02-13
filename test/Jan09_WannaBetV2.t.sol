// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {WannaBetV2, Side, BetTokenData} from "../src/Jan09_WannaBetV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";


contract WannaBetV2Test is Test {
    WannaBetV2 public betContract;
    address alice;
    address bob;
    address charlie;
    IERC20 usdc;
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), 18800000); // ETH Price 2254.51
        betContract = new WannaBetV2(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 0x0000000000000000000000000000000000000348, FeedRegistryInterface(0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf));
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        deal(address(usdc), alice, 10000*1e6);
        deal(address(usdc), bob, 10000*1e6);
        vm.prank(alice);
        usdc.approve(address(betContract), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(betContract), type(uint256).max);
        vm.makePersistent(address(usdc));
        
    }
    function test_wagerCreateReverts() public {
        vm.prank(bob);
        // Bob tries to bet that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        // Doesn't send value, expect revert in value check
        vm.expectRevert("Incorrect ETH amount");
        betContract.createBet(2280*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp + 2 days);

        // Accidentally sets the timestamp to not be in the future, expect it to revert
        vm.expectRevert("Bet end is in the past");
        betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp, block.timestamp + 2 days);
        
        // Accidentally sets the taker accept deadline timestamp to not be in the future, expect it to revert
        vm.expectRevert("Taker deadline cannot be in the past nor after settling timestamp");
        betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp);
        
        // Accidentally sets the taker accept deadline timestamp to be after the settling timestamp (allows you to game his bet and wait for the last moment)
        vm.expectRevert("Taker deadline cannot be in the past nor after settling timestamp");
        betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp + 6 days);
    }
    function test_wagerAcceptReverts() public {
        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp + 2 days);

        vm.prank(alice);
        // Alice tries to accept bet with .5 ETH when bob set the counterparty at 1 ETH, expect revert
        vm.expectRevert("Incorrect ETH amount");
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
        // Bob bets 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp + 2 days);
        vm.stopPrank();

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId); // Alice accepts the bet
        vm.rollFork(18850000); // ETH Price 2292.91807
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling

        assertEq(bob.balance, 11 ether);
    }
    function test_WagerLoss() public {

        vm.prank(bob);
        // Bob bets 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.UNDER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp + 2 days);

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId);
        vm.rollFork(18850000); // ETH Price 2292.91807
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling

        assertEq(bob.balance, 9 ether);
        assertEq(alice.balance, 11 ether);
    }
    function test_WagerLoss2() public {

        vm.prank(bob);
        // Bob bets 1 ETH that ETH is over 2400 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2400*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp + 2 days);

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId);
        vm.rollFork(18841000); // ETH Price 2303.7560007
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling

        assertEq(bob.balance, 9 ether);
        assertEq(alice.balance, 11 ether);
    }
    function test_WagerWithTokens() public {
        vm.prank(bob);
        // Bob bets 100 usdc that ETH is over 2280 USDC in 5 days, wants 0.1 ETH from taker, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet(2280*1e8, Side.OVER, BetTokenData(address(usdc), 100*1e6, address(0), 0.1 ether), block.timestamp + 5 days, block.timestamp + 2 days);
        vm.stopPrank();

        vm.prank(alice);
        betContract.acceptBet{value: 0.1 ether}(betId); // Alice accepts the bet
        vm.rollFork(18850000); // ETH Price 2292.91807
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling

        assertEq(usdc.balanceOf(bob), 10000*1e6); // usdc gets returned
        assertEq(bob.balance, 10.1 ether); // wins .1 eth
    }
    function test_WagerLossWithTokens() public {

        vm.prank(bob);
         // Bob bets 0.1 ETH that ETH is under 2280 USDC in 5 days, wants 100 usdc from taker with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 0.1 ether}(2280*1e8, Side.UNDER, BetTokenData(address(0), 0.1 ether, address(usdc), 100*1e6), block.timestamp + 5 days, block.timestamp + 2 days);

        vm.prank(alice);
        betContract.acceptBet(betId);
        vm.rollFork(18850000); // ETH Price 2292.91807
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling

        assertEq(bob.balance, 9.9 ether); // loses .1 eth
        assertEq(alice.balance, 10.1 ether); // wins .1 eth
        assertEq(usdc.balanceOf(alice), 10000*1e6);
    }
    function test_WagerLoss2WithTokens() public {

        vm.prank(bob);
         // Bob bets 100 usdc that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet(2400*1e8, Side.OVER, BetTokenData(address(usdc), 100*1e6, address(usdc), 100*1e6), block.timestamp + 5 days, block.timestamp + 2 days);

        vm.prank(alice);
        betContract.acceptBet(betId);
        vm.rollFork(18841000); // ETH Price 2303.7560007
        betContract.settleBet(betId); // Settle bet after it has ended, subject to ETH price at time of settling

        assertEq(usdc.balanceOf(bob), 9900*1e6);
        assertEq(usdc.balanceOf(alice), 10100*1e6);
    }

    function test_createAndClose() public {
        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days, settles in 5 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp + 2 days);
        vm.warp(block.timestamp + 2.01 days);
        betContract.closeBet(betId);
        assertEq(bob.balance, 10 ether); // Funds get returned

        // Closing again reverts since bet closed
        vm.expectRevert("Bet closed/settled");
        betContract.closeBet(betId);
    }
    function test_createAndCloseTokens() public {
        vm.prank(bob);
        // Bob bets 100 usdc that ETH is over 2400 USDC in 5 days, with a maximum time to accept bet of 2 days, settles in 5 days
        uint256 betId = betContract.createBet(2400*1e8, Side.OVER, BetTokenData(address(usdc), 100*1e6, address(usdc), 100*1e6), block.timestamp + 5 days, block.timestamp + 2 days);
        vm.warp(block.timestamp + 2.01 days);
        assertEq(usdc.balanceOf(bob), 9900*1e6);
        betContract.closeBet(betId);
        assertEq(usdc.balanceOf(bob), 10000*1e6); // Funds get returned

        // Closing again reverts since bet closed
        vm.expectRevert("Bet closed/settled");
        betContract.closeBet(betId);
    }
    function test_createAndCloseRevert() public {
        vm.prank(bob);
        // Bob bets that 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days, settles in 5 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp + 2 days);

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
        assertEq(bob.balance, 9 ether); // Funds don't get returned
    }
    function test_getChainlinkPrice() public {
        int256 price = betContract.getPrice();
        assertEq(price, 2254.51*1e8); // Price at fork block (18800000)
    }
}
