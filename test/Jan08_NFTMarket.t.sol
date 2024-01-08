// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Jan08_NFTMarket.sol";
import {MockERC721} from "solmate/test/utils/mocks/MockERC721.sol";

contract MarketTest is Test {
    address alice;
    address bob;
    MockERC721 nft;
    MockERC721 nft2;

    NFTMarket private market;

    function setUp() public {
        market = new NFTMarket();
        nft = new MockERC721("TestNFT", "TEST");
        nft2 = new MockERC721("TestNFT2", "TEST2");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        nft.mint(bob, 1);
        nft.mint(bob, 2);
        nft.mint(bob, 3);
        nft2.mint(alice, 1);
        nft2.mint(alice, 2);
        nft2.mint(alice, 3);
        vm.prank(bob);
        nft.setApprovalForAll(address(market), true);
        vm.prank(alice);
        nft2.setApprovalForAll(address(market), true);
    }

    function testCreateTrade() public {
        uint256[] memory bobtokensToSell = new uint256[](1);
        bobtokensToSell[0] = 1;
        vm.prank(bob);
        // bob creates trade: 1 TestNFT for 1 TestNFT2
        market.createTrade(address(nft), bobtokensToSell, address(nft2), 1, uint32(block.timestamp)+1);
    }
    function testCreateAndAcceptTradeNFTToNFT() public {
        uint256[] memory bobtokensToSell = new uint256[](1);
        bobtokensToSell[0] = 1;
        uint256[] memory alicetokensToSell = new uint256[](1);
        alicetokensToSell[0] = 1;
        vm.prank(bob);
        // bob creates trade: 1 TestNFT (id 1) for 1 TestNFT2 (any id)
        uint256 tradeId = market.createTrade(address(nft), bobtokensToSell, address(nft2), 1, uint32(block.timestamp)+1);
        
        assertEq(nft2.balanceOf(alice), 3);
        assertEq(nft.balanceOf(alice), 0);
        
        vm.prank(alice);
        market.acceptTrade(tradeId, alicetokensToSell); // sell tokenId 1
        
        assertEq(nft2.balanceOf(alice), 2);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft2.balanceOf(bob), 1);
    }
    function testCreateAndAcceptTradeNFTToMultipleNFTs() public {
        uint256[] memory bobtokensToSell = new uint256[](1);
        bobtokensToSell[0] = 1;
        uint256[] memory alicetokensToSell = new uint256[](2);
        alicetokensToSell[0] = 1;
        alicetokensToSell[1] = 3;
        vm.prank(bob);
        // bob creates trade: 1 TestNFT (id 1) for 2 TestNFT2 (any id)
        uint256 tradeId = market.createTrade(address(nft), bobtokensToSell, address(nft2), 2, uint32(block.timestamp)+1);
        
        assertEq(nft2.balanceOf(alice), 3);
        assertEq(nft.balanceOf(alice), 0);
        
        vm.prank(alice);
        market.acceptTrade(tradeId, alicetokensToSell); // sell ids 1 and 3
        
        assertEq(nft2.balanceOf(alice), 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 2);
        assertEq(nft2.balanceOf(bob), 2);
    }
    function testCreateAndAcceptTradeMultipleNFTsToNFT() public {
        uint256[] memory bobtokensToSell = new uint256[](2);
        bobtokensToSell[0] = 1;
        bobtokensToSell[1] = 2;
        uint256[] memory alicetokensToSell = new uint256[](1);
        alicetokensToSell[0] = 1;
        vm.prank(bob);
        // bob creates trade: 2 TestNFT (id 1,2) for 2 TestNFT2 (any id)
        uint256 tradeId = market.createTrade(address(nft), bobtokensToSell, address(nft2), 1, uint32(block.timestamp)+1);
        
        assertEq(nft2.balanceOf(alice), 3);
        assertEq(nft.balanceOf(alice), 0);
        
        vm.prank(alice);
        market.acceptTrade(tradeId, alicetokensToSell);
        
        assertEq(nft2.balanceOf(alice), 2);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft2.balanceOf(bob), 1);
    }
    function testCreateAndAcceptTradeMultipleNFTsToMultipleNFTs() public {
        uint256[] memory bobtokensToSell = new uint256[](2);
        bobtokensToSell[0] = 1;
        bobtokensToSell[1] = 2;
        uint256[] memory alicetokensToSell = new uint256[](2);
        alicetokensToSell[0] = 1;
        alicetokensToSell[1] = 2;
        vm.prank(bob);
        // bob creates trade: 1 TestNFT (id 1) for 2 TestNFT2 (any id)
        uint256 tradeId = market.createTrade(address(nft), bobtokensToSell, address(nft2), 2, uint32(block.timestamp)+1);
        
        assertEq(nft2.balanceOf(alice), 3);
        assertEq(nft.balanceOf(alice), 0);
        
        vm.prank(alice);
        market.acceptTrade(tradeId, alicetokensToSell); // sell ids 1 and 2
        
        assertEq(nft2.balanceOf(alice), 1);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft2.balanceOf(bob), 2);
    }
    function testCancelTrade() public {
        uint256[] memory bobtokensToSell = new uint256[](2);
        bobtokensToSell[0] = 1;
        bobtokensToSell[1] = 2;
        uint256[] memory alicetokensToSell = new uint256[](2);
        alicetokensToSell[0] = 2;
        alicetokensToSell[1] = 3;
        vm.startPrank(bob);
        // bob creates trade: 2 TestNFT (id 1,2) for 2 TestNFT2 (any id)
        uint256 tradeId = market.createTrade(address(nft), bobtokensToSell, address(nft2), 2, uint32(block.timestamp)+1);
        market.cancelTrade(tradeId);
        vm.stopPrank();
        // try to accept trade after cancel: expect revert
        vm.prank(alice);
        vm.expectRevert("Trade closed");
        market.acceptTrade(tradeId, alicetokensToSell);
    }
    function testCancelTradeRevertOnWrongCreator() public {
        uint256[] memory bobtokensToSell = new uint256[](2);
        bobtokensToSell[0] = 1;
        bobtokensToSell[1] = 2;
        uint256[] memory alicetokensToSell = new uint256[](2);
        alicetokensToSell[0] = 2;
        alicetokensToSell[1] = 3;
        vm.prank(bob);
        // bob creates trade: 2 TestNFT (id 1,2) for 2 TestNFT2 (any id)
        uint256 tradeId = market.createTrade(address(nft), bobtokensToSell, address(nft2), 2, uint32(block.timestamp)+1);
        // try to cancel as Alice
        vm.prank(alice);
        vm.expectRevert("You are not the creator of the trade");
        market.cancelTrade(tradeId);
    }
    function testCancelTradeRevertOnClosure() public {
        uint256[] memory bobtokensToSell = new uint256[](2);
        bobtokensToSell[0] = 1;
        bobtokensToSell[1] = 2;
        uint256[] memory alicetokensToSell = new uint256[](2);
        alicetokensToSell[0] = 2;
        alicetokensToSell[1] = 3;
        vm.prank(bob);
        // bob creates trade: 2 TestNFT (id 1,2) for 2 TestNFT2 (any id)
        uint256 tradeId = market.createTrade(address(nft), bobtokensToSell, address(nft2), 2, uint32(block.timestamp)+1);
        vm.prank(alice);
        // alice accepts
        market.acceptTrade(tradeId, alicetokensToSell);
        vm.prank(bob);
        vm.expectRevert("Trade closed");
        market.cancelTrade(tradeId);
    }
    function testCreateTradeRevertOnDeadline() public {
        uint256[] memory bobtokensToSell = new uint256[](2);
        bobtokensToSell[0] = 1;
        bobtokensToSell[1] = 2;
        uint256[] memory alicetokensToSell = new uint256[](2);
        alicetokensToSell[0] = 2;
        alicetokensToSell[1] = 3;
        vm.prank(bob);
        // bob creates trade: 2 TestNFT (id 1,2) for 2 TestNFT2 (any id)
        uint256 tradeId = market.createTrade(address(nft), bobtokensToSell, address(nft2), 2, uint32(block.timestamp)+1);
        vm.prank(alice);
        vm.warp(block.timestamp+2);
        // alice accepts
        vm.expectRevert("Too late");
        market.acceptTrade(tradeId, alicetokensToSell);
    }
    function testAcceptTradeRevertOnMismatch() public {
        uint256[] memory bobtokensToSell = new uint256[](2);
        bobtokensToSell[0] = 1;
        bobtokensToSell[1] = 2;
        uint256[] memory alicetokensToSell = new uint256[](1);
        alicetokensToSell[0] = 2;
        vm.prank(bob);
        // bob creates trade: 2 TestNFT (id 1,2) for 2 TestNFT2 (any id)
        uint256 tradeId = market.createTrade(address(nft), bobtokensToSell, address(nft2), 2, uint32(block.timestamp)+1);
        vm.prank(alice);
        // alice accepts
        vm.expectRevert("Token amount mismatch"); // expect revert as 2 nft was requested and alice wants to give 1
        market.acceptTrade(tradeId, alicetokensToSell);
    }
}