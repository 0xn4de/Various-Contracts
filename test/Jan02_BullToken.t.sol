// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {BullToken, AggregatorV3Interface} from "../src/Jan02_BullToken.sol";
contract BullTokenTest is Test {
    BullToken public token;
    AggregatorV3Interface priceFeed;
    address alice;
    address bob;
    address charlie;
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl('mainnet'), 18800000); // ETH Price 2254.51
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        vm.prank(bob);
        token = new BullToken("Bull Token", "BULL", 18, 1_000_000*1e18, 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        vm.makePersistent(address(token));
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      TRANSFER TESTS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function test_priceBelowTransfer() public {
        vm.rollFork(18810000); // Price 2164.456887
        vm.prank(bob);
        // Try to send alice 1000 tokens, fails because current price is too low
        vm.expectRevert("Price is too low");
        token.transfer(alice, 1000*1e18); 

        assertEq(token.balanceOf(bob), 1_000_000*1e18); // Bob still has his tokens
    }
    function test_priceAboveTransfer() public {
        vm.rollFork(18850000); // Price 2292.91807
        vm.prank(bob);
        token.transfer(alice, 1000*1e18); 

        assertEq(token.balanceOf(alice), 1000*1e18); 
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      TRANSFERFROM TESTS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/


    function test_priceAboveTransferFrom() public {
        vm.rollFork(18850000); // Price 2292.91807
        vm.prank(bob);
        token.approve(alice, 10000*1e18); // approve alice for 10k tokens

        vm.prank(alice);
        token.transferFrom(bob, charlie, 10000*1e18); // Send 10k tokens to charlie using bob's approval

        assertEq(token.balanceOf(charlie), 10000*1e18);
    }
    function test_priceBelowTransferFrom() public {
        vm.rollFork(18810000); // Price 2164.456887
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
        vm.rollFork(18850000); // Price 2292.91807
        vm.prank(bob);
        token.transfer(alice, 1000*1e18); 

        assertEq(token.balanceOf(alice), 1000*1e18);
        assertFalse(oldPrice == token.minPrice()); // Check that old price is is updated
        assertFalse(oldUpdated == token.lastUpdated()); // Check that old update time is updated
        assertEq(token.minPrice(), token.getPrice()); // Check that new price is current price
        assertEq(token.lastUpdated(), block.timestamp); // Check that updated time is right now
    }
}
