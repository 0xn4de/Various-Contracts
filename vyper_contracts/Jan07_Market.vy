from vyper.interfaces import ERC20


struct Trade:
    filledOrCancelled: bool
    deadline: uint256
    maker: address
    assetToSell: address
    assetToBuy: address
    amountToSell: uint256
    amountToBuy: uint256


totalTrades: public(uint256)

trades: public(HashMap[uint256, Trade])


@external
@payable
def createTrade(assetToSell: address, amountToSell: uint256, assetToBuy: address, amountToBuy: uint256, deadline: uint256) -> uint256:
    assert deadline > block.timestamp, "Deadline is in the past"
    assert amountToSell > 0, "Can not sell zero"
    self.totalTrades += 1
    if assetToSell == empty(address):
        assert msg.value == amountToSell, "No ETH sent"
    self.trades[self.totalTrades] = Trade({
        filledOrCancelled: False,
        deadline: deadline,
        maker: msg.sender,
        assetToSell: assetToSell,
        assetToBuy: assetToBuy,
        amountToSell: amountToSell,
        amountToBuy: amountToBuy
    })
    return self.totalTrades

@external
@payable
def acceptTrade(tradeId: uint256):
    trade: Trade = self.trades[tradeId]
    assert block.timestamp < trade.deadline, "Too late"
    assert not trade.filledOrCancelled, "Trade closed"
    self.trades[tradeId].filledOrCancelled = True
    if trade.assetToSell == empty(address) or trade.assetToBuy == empty(address):
        if trade.assetToSell == empty(address) and trade.assetToBuy != empty(address):
            ERC20(trade.assetToBuy).transferFrom(msg.sender, trade.maker, trade.amountToBuy)
            raw_call(msg.sender, b'', value=trade.amountToSell)
        elif trade.assetToSell != empty(address) and trade.assetToBuy == empty(address):
            assert msg.value == trade.amountToBuy, "No ETH sent"
            ERC20(trade.assetToSell).transferFrom(trade.maker, msg.sender, trade.amountToSell)
            raw_call(trade.maker, b'', value=trade.amountToBuy)
        else:
            assert msg.value == trade.amountToBuy, "No ETH sent"
            raw_call(trade.maker, b'', value=trade.amountToBuy)
            raw_call(msg.sender, b'', value=trade.amountToSell)
    else:
        ERC20(trade.assetToBuy).transferFrom(msg.sender, trade.maker, trade.amountToBuy)
        ERC20(trade.assetToSell).transferFrom(trade.maker, msg.sender, trade.amountToSell)

@external
def cancelTrade(tradeId: uint256):
    trade: Trade = self.trades[tradeId]
    assert msg.sender == trade.maker, "You are not the creator of the trade"
    assert not trade.filledOrCancelled, "Trade closed"
    self.trades[tradeId].filledOrCancelled = True
    if trade.assetToSell == empty(address):
        raw_call(msg.sender, b'', value=trade.amountToSell)