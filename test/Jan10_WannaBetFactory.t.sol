// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {WannaBetFactory, WannaBetV2} from "../src/Jan10_WannaBetFactory.sol";
import {Side, BetTokenData} from "../src/Jan09_WannaBetV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract WannaBetFactoryTest is Test {
    WannaBetFactory public factory;
    address alice;
    address bob;
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), 18800000);
        factory = new WannaBetFactory(0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testDeployPool() public {
        // deploy ETH-USD pool
        address pool = factory.deploy(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,0x0000000000000000000000000000000000000348);
        assert(WannaBetV2(pool).getPrice() > 0); // check its returning a price
        assert(factory.pools(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,0x0000000000000000000000000000000000000348) == pool); // check mapping
    }
    function testDeployPoolRevertsWithWrongAddress() public {
        vm.expectRevert("Feed not found");
        factory.deploy(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,0x0000000000000000000000000000000000000347);
    }
    function testDeployAndWager() public {
        WannaBetV2 betContract = WannaBetV2(factory.deploy(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,0x0000000000000000000000000000000000000348));

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
    function testDeployingPoolTwiceReverts() public {
        // deploy ETH-USD pool
        factory.deploy(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,0x0000000000000000000000000000000000000348);
        vm.expectRevert("Pool already deployed");
        factory.deploy(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,0x0000000000000000000000000000000000000348);
    }
}
