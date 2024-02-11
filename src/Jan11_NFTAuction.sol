pragma solidity ^0.8.0;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ERC6909} from "solmate/tokens/ERC6909.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

struct Auction {
    bool finished;
    NFT nftType;
    address maker;
    address currentBidder;
    address nft;
    uint256 tokenId;
    uint256 reserve;
    uint256 minRaise;
    uint256 buyNow;
    uint256 currentBid;
    uint256 deadline;
}
enum NFT { ERC721, ERC6909 }

contract NFTAuction is ERC721TokenReceiver {
    using SafeTransferLib for ERC721;

    uint256 totalAuctions;
    mapping (uint256 => Auction) public auctions;

    event AuctionCreated(address nft, uint256 tokenId, uint256 reserve, uint256 minRaise, uint256 buyNow, uint256 deadline);
    event AuctionSettled(uint256 indexed auctionId, address indexed buyer, uint256 indexed bidAmount);
    event Bid(uint256 indexed auctionId, address indexed bidder, uint256 indexed bidAmount);
    event AuctionClosed(uint256 indexed auctionId);

    function createAuction(address nft, uint256 tokenId, NFT nftType, uint256 reserve, uint256 minRaise, uint256 buyNow, uint256 auctionLength) external returns (uint256) {
        if (buyNow > 0) { // sometimes no buy now
            require(reserve < buyNow, "Reserve is too high"); // prevent the first bid from finishing auction (due to bid > buyNow check, can't bid less than reserve)
        }
        require(minRaise > 0, "Have to set a minimum raise");
        uint256 auctionId = ++totalAuctions;
        if (nftType == NFT.ERC721) {
            ERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);
        } else if (nftType == NFT.ERC6909) {
            ERC6909(nft).transferFrom(msg.sender, address(this), tokenId, 1);
        }
        auctions[auctionId] = Auction(false, nftType, msg.sender, address(0), nft, tokenId, reserve, minRaise, buyNow, 0, block.timestamp+auctionLength);
        emit AuctionCreated(nft, tokenId, reserve, minRaise, buyNow, block.timestamp+auctionLength);
        return auctionId;
    }

    function bid(uint256 auctionId) external payable returns (bool) {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp < auction.deadline, "Too late");
        require(!auction.finished, "Auction closed");
        require(msg.value > auction.currentBid+auction.minRaise, "Bid more");

        if (auction.currentBidder != address(0)) {
            uint256 lastBid = auction.currentBid;
            auction.currentBid = 0; // prevent re-entrancy
            // possibly open to DoS through bidding through a contract
            SafeTransferLib.safeTransferETH(auction.currentBidder, lastBid); // refund last bidder
        }

        auction.currentBidder = msg.sender;
        auction.currentBid = msg.value;

        if (msg.value >= auction.buyNow && auction.buyNow != 0) {
            auction.finished = true;
            if (auction.nftType == NFT.ERC721) {
                ERC721(auction.nft).safeTransferFrom(address(this), msg.sender, auction.tokenId);
            } else if (auction.nftType == NFT.ERC6909) {
                ERC6909(auction.nft).transferFrom(address(this), msg.sender, auction.tokenId, 1);
            }
            SafeTransferLib.safeTransferETH(auction.maker, msg.value);
            emit AuctionSettled(auctionId, msg.sender, msg.value);
            return true;
        }
        emit Bid(auctionId, msg.sender, msg.value);
        return true;
    }
    function settleAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp > auction.deadline, "Too early");
        require(!auction.finished, "Auction closed");
        auction.finished = true;
        uint256 lastBid = auction.currentBid;
        auction.currentBid = 0; // prevent re-entrancy
        if (lastBid >= auction.reserve) {
            if (auction.nftType == NFT.ERC721) {
                ERC721(auction.nft).safeTransferFrom(address(this), auction.currentBidder, auction.tokenId);
            } else if (auction.nftType == NFT.ERC6909) {
                ERC6909(auction.nft).transfer(auction.currentBidder, auction.tokenId, 1);
            }
            SafeTransferLib.safeTransferETH(auction.maker, lastBid);
        } else {
            SafeTransferLib.safeTransferETH(auction.currentBidder, lastBid);
        }
        emit AuctionSettled(auctionId, auction.currentBidder, lastBid);

    }
    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(msg.sender == auction.maker, "You are not the creator of the auction");
        require(!auction.finished, "Auction closed");
        auction.finished = true;
        if (auction.nftType == NFT.ERC721) {
            ERC721(auction.nft).safeTransferFrom(address(this), msg.sender, auction.tokenId);
        } else if (auction.nftType == NFT.ERC6909) {
            ERC6909(auction.nft).transfer(msg.sender, auction.tokenId, 1);
        }
        // possible DoS again
        if (auction.currentBidder != address(0)) {
            SafeTransferLib.safeTransferETH(auction.maker, auction.currentBid);
        }
        emit AuctionClosed(auctionId);
    }
}