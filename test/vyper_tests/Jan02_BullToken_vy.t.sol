// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {BullToken} from "../../src/Jan02_BullToken.sol";
import "vyper/VyperDeployer.sol";
contract AggregatorV3Interface {
    int256 public price;
    function setData(int256 data) public {
        price = data;
    }
    function latestRoundData() external view returns (uint256, int256, uint256, uint256, uint256) {
        return (0, price, 1,2,3);
    }
}
contract BullTokenTest is Test {
    BullToken public token;
    AggregatorV3Interface priceFeed;
    VyperDeployer vyperDeployer = new VyperDeployer();
    address alice;
    address bob;
    address charlie;
    function setUp() public {
        //vm.createSelectFork(vm.rpcUrl('mainnet'), 18800000); // ETH Price 2254.51
        alice = makeAddr("alice");
        bob = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f; // vyperdeployer address
        charlie = makeAddr("charlie");
        priceFeed = new AggregatorV3Interface();
        priceFeed.setData(2254*1e8);
        vm.prank(bob);
        token = BullToken(vyperDeployer.deployContract("Jan02_BullToken", abi.encode("Bull Token", "BULL", 18, 1_000_000*1e18, address(priceFeed))));
        vm.makePersistent(address(token));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      TRANSFER TESTS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function test_priceBelowTransfer() public {
        //vm.rollFork(18810000); // Price 2164.456887
        priceFeed.setData(2164.456887*1e8);
        vm.prank(bob);
        // Try to send alice 1000 tokens, fails because current price is too low
        vm.expectRevert("Price is too low");
        token.transfer(alice, 1000*1e18); 

        assertEq(token.balanceOf(bob), 1_000_000*1e18); // Bob still has his tokens
    }
    function test_priceAboveTransfer() public {
        //vm.rollFork(18850000); // Price 2292.91807
        priceFeed.setData(2292.91807*1e8);
        vm.prank(bob);
        token.transfer(alice, 1000*1e18); 

        assertEq(token.balanceOf(alice), 1000*1e18); 
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      TRANSFERFROM TESTS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/


    function test_priceAboveTransferFrom() public {
        //vm.rollFork(18850000); // Price 2292.91807
        priceFeed.setData(2292.91807*1e8);
        vm.prank(bob);
        token.approve(alice, 10000*1e18); // approve alice for 10k tokens

        vm.prank(alice);
        token.transferFrom(bob, charlie, 10000*1e18); // Send 10k tokens to charlie using bob's approval

        assertEq(token.balanceOf(charlie), 10000*1e18);
    }
    function test_priceBelowTransferFrom() public {
        //vm.rollFork(18810000); // Price 2164.456887
        priceFeed.setData(2164.456887*1e8);
        vm.prank(bob);
        token.approve(alice, 10000*1e18); // approve alice for 10k tokens
        
        vm.prank(alice);
        vm.expectRevert("Price is too low");
        token.transferFrom(bob, charlie, 10000*1e18); // Send 10k tokens to charlie using bob's approval

        assertEq(token.balanceOf(bob), 1_000_000*1e18); // Bob still has his tokens
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRICE UPDATE TEST                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function test_updateOnTransfer() public {
        int256 oldPrice = token.minPrice();
        uint256 oldUpdated = token.lastUpdated();
        //vm.rollFork(18850000); // Price 2292.91807
        vm.warp(1 weeks + 2 seconds);
        priceFeed.setData(2292.91807*1e8);
        vm.prank(bob);
        token.transfer(alice, 1000*1e18); 

        assertEq(token.balanceOf(alice), 1000*1e18);
        assertFalse(oldPrice == token.minPrice()); // Check that old price is is updated
        assertFalse(oldUpdated == token.lastUpdated()); // Check that old update time is updated
        assertEq(token.minPrice(), 2292.91807*1e8); // Check that new price is current price
        assertEq(token.lastUpdated(), block.timestamp); // Check that updated time is right now
    }
}
