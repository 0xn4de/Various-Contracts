pragma solidity ^0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

struct Trade {
    bool filledOrCancelled;
    uint32 deadline;
    address maker;
    address nftToBuy; // ERC721 address
    address nftToSell; // ERC721 address
    uint256 tokensToBuy; // amount of other collection tokens owner wants back (TODO: specify tokens)
    uint256[] tokensToSell; // list of tokenIds owner wants to trade (so we know what ids to send)
}
// TODO: ETH, ERC20, ERC721, ERC1155 market, not just erc721-erc721
contract NFTMarket {
    using SafeTransferLib for ERC721;

    uint256 totalTrades;
    mapping (uint256 => Trade) public trades;

    event TradeCreated(address nftToSell, uint256[] tokensToSell, address nftToBuy, uint256 tokensToBuy, uint32 deadline);
    event TradeCancelled(uint256 indexed tradeId, address indexed creator);
    event TradeAccepted(uint256 indexed tradeId, address indexed nft1, address indexed nft2, uint256[] nft1Ids, uint256[] nft2Ids, address maker, address taker);

    function createTrade(address nftToSell, uint256[] calldata tokensToSell, address nftToBuy, uint256 tokensToBuy, uint32 deadline) public returns (uint256) {
        require(deadline > block.timestamp, "Deadline is in the past");
        require(tokensToSell.length > 0, "Can not sell zero");
        uint256 tradeId = ++totalTrades;
        trades[tradeId] = Trade(false, deadline, msg.sender, nftToBuy, nftToSell, tokensToBuy, tokensToSell);
        emit TradeCreated(nftToSell, tokensToSell, nftToBuy, tokensToBuy, deadline);
        return tradeId;
    }

    function acceptTrade(uint256 tradeId, uint256[] calldata tokensToSell) public {
        Trade storage trade = trades[tradeId];
        require(block.timestamp < trade.deadline, "Too late");
        require(!trade.filledOrCancelled, "Trade closed");
        require(tokensToSell.length == trade.tokensToBuy, "Token amount mismatch");
        trade.filledOrCancelled = true;
        for (uint256 i = 0; i < trade.tokensToSell.length; i++) {
            ERC721(trade.nftToSell).safeTransferFrom(trade.maker, msg.sender, trade.tokensToSell[i]);
        }
        for (uint256 i = 0; i < tokensToSell.length; i++) {
            ERC721(trade.nftToBuy).safeTransferFrom(msg.sender, trade.maker, tokensToSell[i]);
        }
        emit TradeAccepted(tradeId, trade.nftToSell, trade.nftToBuy, trade.tokensToSell, tokensToSell, trade.maker, msg.sender);
    }
    function cancelTrade(uint256 tradeId) public {
        Trade storage trade = trades[tradeId];
        require(msg.sender == trade.maker, "You are not the creator of the trade");
        require(!trade.filledOrCancelled, "Trade closed");
        trade.filledOrCancelled = true;
        emit TradeCancelled(tradeId, msg.sender);
    }

}