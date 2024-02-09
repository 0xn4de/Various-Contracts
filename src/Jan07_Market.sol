pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

struct Trade {
    bool filledOrCancelled;
    uint32 deadline;
    address maker;
    address assetToSell;
    address assetToBuy;
    uint256 amountToSell;
    uint256 amountToBuy;
}
contract Market {
    using SafeTransferLib for ERC20;

    uint256 totalTrades;
    mapping (uint256 => Trade) public trades;

    event TradeCreated(address assetToSell, uint256 amountToSell, address assetToBuy, uint256 amountToBuy, uint32 deadline);
    event TradeCancelled(uint256 indexed tradeId, address indexed creator);

    function createTrade(address assetToSell, uint256 amountToSell, address assetToBuy, uint256 amountToBuy, uint32 deadline) public payable returns (uint256) {
        require(deadline > block.timestamp, "Deadline is in the past");
        require(amountToSell > 0, "Can not sell zero");
        uint256 tradeId = ++totalTrades;
        if (assetToSell == address(0)) {
            require(msg.value == amountToSell, "No ETH sent");
        }
        trades[tradeId] = Trade(false, deadline, msg.sender, assetToSell, assetToBuy, amountToSell, amountToBuy);
        emit TradeCreated(assetToSell, amountToSell, assetToBuy, amountToBuy, deadline);
        return tradeId;
    }

    // leaves opportunity for gas griefing at the expense of the accepter, creator can be contract
    // also (possibly) an opportunity for fake contracts to act like they're transferring but aren't
    // up to the accepter to verify
    function acceptTrade(uint256 tradeId) public payable {
        Trade storage trade = trades[tradeId];
        require(block.timestamp < trade.deadline, "Too late");
        require(!trade.filledOrCancelled, "Trade closed");
        trade.filledOrCancelled = true;
        if (trade.assetToSell == address(0) || trade.assetToBuy == address(0)) {
            if (trade.assetToSell == address(0) && trade.assetToBuy != address(0)) { // ETH for ERC20
                ERC20(trade.assetToBuy).safeTransferFrom(msg.sender, trade.maker, trade.amountToBuy);
                SafeTransferLib.safeTransferETH(msg.sender, trade.amountToSell);
            } else if (trade.assetToSell != address(0) && trade.assetToBuy == address(0)) { // ERC20 for ETH
                require(msg.value == trade.amountToBuy, "No ETH sent");
                ERC20(trade.assetToSell).safeTransferFrom(trade.maker, msg.sender, trade.amountToSell);
                SafeTransferLib.safeTransferETH(trade.maker, trade.amountToBuy);
            } else { // ETH-ETH (for some reason)
                require(msg.value == trade.amountToBuy, "No ETH sent");
                SafeTransferLib.safeTransferETH(trade.maker, trade.amountToBuy);
                SafeTransferLib.safeTransferETH(msg.sender, trade.amountToSell);
            }
        } else {
            ERC20(trade.assetToBuy).safeTransferFrom(msg.sender, trade.maker, trade.amountToBuy);
            ERC20(trade.assetToSell).safeTransferFrom(trade.maker, msg.sender, trade.amountToSell);
        }
    }
    function cancelTrade(uint256 tradeId) public {
        Trade storage trade = trades[tradeId];
        require(msg.sender == trade.maker, "You are not the creator of the trade");
        require(!trade.filledOrCancelled, "Trade closed");
        trade.filledOrCancelled = true;
        if (trade.assetToSell == address(0)) {
            SafeTransferLib.safeTransferETH(msg.sender, trade.amountToSell);
        }
        emit TradeCancelled(tradeId, msg.sender);
    }

}