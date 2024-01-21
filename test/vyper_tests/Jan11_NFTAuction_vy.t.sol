// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {NFTAuction, NFT} from "../../src/Jan11_NFTAuction.sol";
import {MockERC721} from "solmate/test/utils/mocks/MockERC721.sol";
import {MockERC6909} from "solmate/test/utils/mocks/MockERC6909.sol";
import "vyper/VyperDeployer.sol";


contract NFTAuctionTest is Test {
    address alice;
    address bob;
    MockERC721 nft;
    MockERC6909 nft2;

    VyperDeployer vyperDeployer = new VyperDeployer();
    NFTAuction private auction;

    function setUp() public {
        auction = NFTAuction(vyperDeployer.deployContract("Jan11_NFTAuction"));
        nft = new MockERC721("TestNFT", "TEST"); // 721
        nft2 = new MockERC6909(); // 6909

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        nft.mint(alice, 1);
        nft2.mint(alice, 1, 5);

        vm.startPrank(alice);
        nft.setApprovalForAll(address(auction), true);
        nft2.approve(address(auction), 1, 5);
        vm.stopPrank();
    }

    function testCreateAuctions() public {
        vm.startPrank(alice);
        // alice creates an auction for nft tokenId 1 with a reserve of 0.1 eth, min raise as 0.01 ether and buy now at 0.5 ether for 1 day
        auction.createAuction(address(nft), 1, NFT.ERC721, 0.1 ether, 0.01 ether, 0.5 ether, 1 days);
        auction.createAuction(address(nft2), 1, NFT.ERC6909, 0.1 ether, 0.01 ether, 0.5 ether, 1 days);
        vm.stopPrank();
    }

    function testBuyNow() public {
        assertEq(nft.balanceOf(alice), 1);
        // alice creates an auction for nft tokenId 1 with a reserve of 0.1 eth, min raise as 0.01 ether and buy now at 0.5 ether for 1 day
        vm.prank(alice);
        uint256 auctionId = auction.createAuction(address(nft), 1, NFT.ERC721, 0.1 ether, 0.01 ether, 0.5 ether, 1 days);
        
        assertEq(nft.balanceOf(alice), 0);
        
        vm.prank(bob);
        auction.bid{value:0.5 ether}(auctionId); // Buy Now
        
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(alice.balance, 10.5 ether);
    }
    function testBidAndSettle() public {
        assertEq(nft.balanceOf(alice), 1);
        // alice creates an auction for nft tokenId 1 with a reserve of 0.1 eth, min raise as 0.01 ether and buy now at 0.5 ether for 1 day
        vm.prank(alice);
        uint256 auctionId = auction.createAuction(address(nft), 1, NFT.ERC721, 0.1 ether, 0.01 ether, 0.5 ether, 1 days);
        
        assertEq(nft.balanceOf(alice), 0);
        
        vm.prank(bob);
        auction.bid{value:0.25 ether}(auctionId); // make .25 eth bid
    
        vm.warp(block.timestamp + 1 days + 1 seconds);
        auction.settleAuction(auctionId);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(alice.balance, 10.25 ether);
    }
    function testBuyNow6909() public {
        assertEq(nft2.balanceOf(alice, 1), 5);
        // alice creates an auction for nft2 tokenId 1 with a reserve of 0.1 eth, min raise as 0.01 ether and buy now at 0.5 ether for 1 day
        vm.prank(alice);
        uint256 auctionId = auction.createAuction(address(nft2), 1, NFT.ERC6909, 0.1 ether, 0.01 ether, 0.5 ether, 1 days);
        
        assertEq(nft2.balanceOf(alice, 1), 4);
        
        vm.prank(bob);
        auction.bid{value:0.25 ether}(auctionId); // make .25 eth bid
    
        vm.warp(block.timestamp + 1 days + 1 seconds);
        auction.settleAuction(auctionId);

        assertEq(nft2.balanceOf(alice, 1), 4);
        assertEq(nft2.balanceOf(bob, 1), 1);
        assertEq(alice.balance, 10.25 ether);
    }
    function testBidAndSettle6909() public {
        assertEq(nft2.balanceOf(alice, 1), 5);
        // alice creates an auction for nft2 tokenId 1 with a reserve of 0.1 eth, min raise as 0.01 ether and buy now at 0.5 ether for 1 day
        vm.prank(alice);
        uint256 auctionId = auction.createAuction(address(nft2), 1, NFT.ERC6909, 0.1 ether, 0.01 ether, 0.5 ether, 1 days);
        
        assertEq(nft2.balanceOf(alice, 1), 4);
        
        vm.prank(bob);
        auction.bid{value:0.5 ether}(auctionId); // Buy Now

        assertEq(nft2.balanceOf(alice, 1), 4);
        assertEq(nft2.balanceOf(bob, 1), 1);
        assertEq(alice.balance, 10.5 ether);
    }
}