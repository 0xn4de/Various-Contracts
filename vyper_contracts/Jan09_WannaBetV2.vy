
from vyper.interfaces import ERC20

interface FeedRegistryInterface:
    def latestRoundData(base: address, quote: address) -> (uint256, int256, uint256, uint256, uint256): view

struct BetTokenData:
    makerAsset: address
    makerBet: uint256
    takerAsset: address
    takerBet: uint256

struct BetData:
    settledOrClosed: bool
    taker: address
    maker: address
    makerBetSide: uint8
    tokenData: BetTokenData
    ends: uint256
    takerDeadline: uint256
    price: int256

registry: public(FeedRegistryInterface)
base: public(address)
quote: public(address)
wagers: public(uint256)
bets: public(HashMap[uint256, BetData])
initialized: public(bool)

event betCreated:
    maker: indexed(address)
    price: indexed(int256)
    betId: indexed(uint256)
    tokenData: BetTokenData
    ends: uint256
    takerDeadline: uint256
    side: uint8
event betSettled:
    winner: indexed(address)
    betId: indexed(uint256)
    token1: address
    amount1: uint256
    token2: address
    amount2: uint256
event betClosed:
    betId: indexed(uint256)
    maker: indexed(address)
event betAccepted:
    betId: indexed(uint256)
    taker: indexed(address)
@external
def initialize(_base: address, _quote: address, _registry: FeedRegistryInterface):
    assert not self.initialized
    self.registry = _registry
    self.base = _base
    self.quote = _quote
    self.initialized = True
@external
@payable
def createBet(price: int256, side: uint8, tokenData: BetTokenData, ends: uint256, takerDeadline: uint256) -> uint256:
    assert side < 2, "Wrong side"
    assert ends > block.timestamp, "Bet end is in the past"
    assert takerDeadline > block.timestamp and takerDeadline < ends, "Taker deadline cannot be in the past nor after settling timestamp"
    self.wagers += 1
    if tokenData.makerAsset == empty(address):
        assert msg.value == tokenData.makerBet, "Incorrect ETH amount"
    else:
        ERC20(tokenData.makerAsset).transferFrom(msg.sender, self, tokenData.makerBet)
    self.bets[self.wagers] = BetData({
        settledOrClosed: False,
        taker: empty(address),
        maker: msg.sender,
        makerBetSide: side,
        tokenData: tokenData,
        ends: ends,
        takerDeadline: takerDeadline,
        price: price
    })
    log betCreated(msg.sender, price, self.wagers, tokenData, ends, takerDeadline, side)
    return self.wagers

@external
@payable
def acceptBet(betId: uint256):
    bet: BetData = self.bets[betId]
    assert bet.takerDeadline > block.timestamp, "Too late, bet closed"
    assert bet.taker == empty(address), "Someone already bet"
    if bet.tokenData.takerAsset == empty(address):
        assert msg.value == bet.tokenData.takerBet, "Incorrect ETH amount"
    else:
        ERC20(bet.tokenData.takerAsset).transferFrom(msg.sender, self, bet.tokenData.takerBet)
    self.bets[betId].taker = msg.sender
    log betAccepted(betId, msg.sender)

@external
def settleBet(betId: uint256):
    bet: BetData = self.bets[betId]
    assert bet.ends < block.timestamp, "Bet has not ended"
    assert not bet.settledOrClosed, "Bet cloesd/settled"
    price: int256 = self.getPrice()
    winner: address = bet.maker
    if not ((price > bet.price and bet.makerBetSide == 1) or (price < bet.price and bet.makerBetSide == 0)):
        winner = bet.taker
    self.bets[betId].settledOrClosed = True
    if bet.tokenData.makerAsset == empty(address) or bet.tokenData.takerAsset == empty(address):
        if bet.tokenData.makerAsset == empty(address) and bet.tokenData.takerAsset != empty(address):
            ERC20(bet.tokenData.takerAsset).transfer(winner, bet.tokenData.takerBet)
            raw_call(winner, b'', value=bet.tokenData.makerBet)
        elif bet.tokenData.makerAsset != empty(address) and bet.tokenData.takerAsset == empty(address):
            ERC20(bet.tokenData.makerAsset).transfer(winner, bet.tokenData.makerBet)
            raw_call(winner, b'', value=bet.tokenData.takerBet)
        else:
            raw_call(winner, b'', value=bet.tokenData.takerBet+bet.tokenData.makerBet)
    else:
        ERC20(bet.tokenData.makerAsset).transfer(winner, bet.tokenData.makerBet)
        ERC20(bet.tokenData.takerAsset).transfer(winner, bet.tokenData.takerBet)
    log betSettled(winner, betId, bet.tokenData.makerAsset, bet.tokenData.makerBet, bet.tokenData.takerAsset, bet.tokenData.takerBet)
@external
def closeBet(betId: uint256):
    bet: BetData = self.bets[betId]
    assert not bet.settledOrClosed, "Bet closed/settled"
    assert bet.takerDeadline < block.timestamp, "Too early"
    assert bet.taker == empty(address), "Bet already accepted"
    self.bets[betId].settledOrClosed = True
    if bet.tokenData.makerAsset == empty(address):
        raw_call(bet.maker, b'', value=bet.tokenData.makerBet)
    else:
        ERC20(bet.tokenData.makerAsset).transfer(bet.maker, bet.tokenData.makerBet)
    log betClosed(betId, msg.sender)
@internal
@view
def getPrice() -> int256:
    a: uint256 = 0
    price: int256 = 0
    b: uint256 = 0
    c: uint256 = 0
    d: uint256 = 0
    (a, price, b, c, d) = self.registry.latestRoundData(self.base, self.quote)
    return price