
from vyper.interfaces import ERC721

struct Trade:
    filledOrCancelled: bool
    deadline: uint256
    maker: address
    nftToBuy: address
    nftToSell: address
    tokensToBuy: uint256
    tokensToSell: DynArray[uint256, 64]


totalTrades: public(uint256)
trades: public(HashMap[uint256, Trade])

event TradeCreated:
    nftToSell: address
    tokensToSell: DynArray[uint256, 64]
    nftToBuy: address
    tokensToBuy: uint256
    deadline: uint256

@external
def createTrade(nftToSell: address, tokensToSell: DynArray[uint256, 64], nftToBuy: address, tokensToBuy: uint256, deadline: uint256) -> uint256:
    assert deadline > block.timestamp, "Deadline is in the past"
    assert len(tokensToSell) > 0, "Can not sell zero"
    self.totalTrades += 1
    self.trades[self.totalTrades] = Trade({
        filledOrCancelled: False,
        deadline: deadline,
        maker: msg.sender,
        nftToBuy: nftToBuy,
        nftToSell: nftToSell,
        tokensToBuy: tokensToBuy,
        tokensToSell: tokensToSell
    })
    log TradeCreated(nftToSell, tokensToSell, nftToBuy, tokensToBuy, deadline)
    return self.totalTrades

@external
def acceptTrade(tradeId: uint256, tokensToSell: DynArray[uint256, 64]):
    trade: Trade = self.trades[tradeId]
    assert block.timestamp < trade.deadline, "Too late"
    assert not trade.filledOrCancelled, "Trade closed"
    assert len(tokensToSell) == trade.tokensToBuy, "Token amount mismatch"
    self.trades[tradeId].filledOrCancelled = True
    for i in trade.tokensToSell:
        ERC721(trade.nftToSell).safeTransferFrom(trade.maker, msg.sender, i, b'')
    for i in tokensToSell:
        ERC721(trade.nftToBuy).safeTransferFrom(msg.sender, trade.maker, i, b'')
    

@external
def cancelTrade(tradeId: uint256):
    assert msg.sender == self.trades[tradeId].maker, "You are not the creator of the trade"
    assert not self.trades[tradeId].filledOrCancelled, "Trade closed"
    self.trades[tradeId].filledOrCancelled = True