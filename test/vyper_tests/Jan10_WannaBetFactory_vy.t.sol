// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {WannaBetFactory, WannaBetV2} from "../../src/Jan10_WannaBetFactory.sol";
import {Side, BetTokenData} from "../../src/Jan09_WannaBetV2.sol";
import "vyper/VyperDeployer.sol";

// extremely experimental
// do ignore all the bad practices :)

contract AggregatorV3Interface {
    int256 public price;
    function setData(int256 data) public {
        price = data;
    }
    function latestRoundData() external view returns (uint256, int256, uint256, uint256, uint256) {
        return (0, price, 1,2,3);
    }
}

contract FeedRegistryInterface {
    int256 public price;
    mapping (address => mapping(address => int256)) prices;
    AggregatorV3Interface public pool;
    function setData(address base, address quote, int256 data) public {
        prices[base][quote] = data;
    }
    function latestRoundData(address base, address quote) external view returns (uint256, int256, uint256, uint256, uint256) {
        return (0, prices[base][quote], 1,2,3);
    }
    constructor() {
        pool = new AggregatorV3Interface();
    }
    function getFeed(address, address) external view returns (address) {
        return address(pool);
    }
}

contract WannaBetFactoryTest is Test {
    WannaBetFactory public factory;
    address alice;
    address bob;
    address eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address usd = 0x0000000000000000000000000000000000000348;
    FeedRegistryInterface registry;
    VyperDeployer vyperDeployer = new VyperDeployer();
    function setUp() public {
        //vm.createSelectFork(vm.rpcUrl('mainnet'), 18800000);
        WannaBetV2 wb = WannaBetV2(vyperDeployer.deployContract("Jan09_WannaBetV2"));
        registry = new FeedRegistryInterface(); 
        factory = WannaBetFactory(vyperDeployer.deployContract("Jan10_WannaBetFactory", abi.encode(registry, address(wb))));
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        registry.setData(eth, usd, 2254.51*1e8);
    }

    function testDeployPool() public {
        // deploy ETH-USD pool
        address pool = factory.deploy(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,0x0000000000000000000000000000000000000348);
        assert(factory.pools(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,0x0000000000000000000000000000000000000348) == pool); // check mapping
    }
    function testDeployAndWager() public {
        WannaBetV2 betContract = WannaBetV2(factory.deploy(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,0x0000000000000000000000000000000000000348));

        vm.prank(bob);
        // Bob bets 1 ETH that ETH is over 2280 USDC in 5 days, with a maximum time to accept bet of 2 days
        uint256 betId = betContract.createBet{value: 1 ether}(2280*1e8, Side.OVER, BetTokenData(address(0), 1 ether, address(0), 1 ether), block.timestamp + 5 days, block.timestamp + 2 days);
        vm.stopPrank();

        vm.prank(alice);
        betContract.acceptBet{value: 1 ether}(betId); // Alice accepts the bet
        //vm.rollFork(18850000); // ETH Price 2292.91807
        vm.warp(block.timestamp + 5.01 days);
        registry.setData(eth, usd, 2292.91807*1e8);
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
