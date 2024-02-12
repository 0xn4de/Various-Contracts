

interface AggregatorV3Interface:
    def latestRoundData() -> (uint256, int256, uint256, uint256, uint256): view

struct BetData:
    taker: address
    maker: address
    makerBetSide: uint8
    makerBet: uint256
    takerBet: uint256
    ends: uint256
    takerDeadline: uint256
    price: int256
    settledOrClosed: bool

event betCreated:
    maker: indexed(address)
    price: indexed(int256)
    betId: indexed(uint256)
    ends: uint256
    takerDeadline: uint256
    takerBet: uint256
    side: uint8
event betSettled:
    winner: indexed(address)
    pot: indexed(uint256)
    betId: indexed(uint256)
event betClosed:
    maker: indexed(address)
    betId: indexed(uint256)
event betAccepted:
    taker: indexed(address)
    betId: indexed(uint256)

priceFeed: public(AggregatorV3Interface)
wagers: public(uint256)
bets: public(HashMap[uint256, BetData])

@external
def __init__(_priceFeed: address):
    self.priceFeed = AggregatorV3Interface(_priceFeed)


@external
@payable
def createBet(price: int256, side: uint8, ends: uint256, takerDeadline: uint256, takerBet: uint256) -> uint256:
    """
    side was originally an enum, but since vyper enum != solidity enum (https://jtriley.substack.com/p/the-vyper-compiler)
    had to change implementation to be uint8
    tests still work using the original solidity Enum in function calls, as Solidity enums are just 0,1,2,3 etc
    encountered same thing in NFTAuction.vy
    """
    assert side < 2, "Wrong side"
    assert msg.value > 0, "No ETH Bet"
    assert ends > block.timestamp, "Bet end is in the past"
    assert takerDeadline > block.timestamp and takerDeadline < ends, "Taker deadline cannot be in the past nor after settling timestamp"
    self.wagers += 1
    self.bets[self.wagers] = BetData({
        taker: empty(address),
        maker: msg.sender,
        makerBetSide: side,
        makerBet: msg.value,
        takerBet: takerBet,
        ends: ends,
        takerDeadline: takerDeadline,
        price: price,
        settledOrClosed: False
    })
    log betCreated(msg.sender, price, self.wagers, ends, takerDeadline, takerBet, side)
    return self.wagers

@internal
@view
def getPrice() -> int256:
    a: uint256 = 0
    price: int256 = 0
    b: uint256 = 0
    c: uint256 = 0
    d: uint256 = 0
    (a, price, b, c, d) = self.priceFeed.latestRoundData()
    return price

@external
@payable
def acceptBet(betId: uint256):
    bet: BetData = self.bets[betId]
    assert bet.takerDeadline > block.timestamp, "Too late, bet closed"
    assert bet.taker == empty(address), "Someone already bet"
    assert bet.takerBet == msg.value, "You bet too little/too much"
    self.bets[betId].taker = msg.sender
    log betAccepted(msg.sender, betId)

@external
def settleBet(betId: uint256):
    bet: BetData = self.bets[betId]
    assert bet.ends < block.timestamp, "Bet has not ended"
    assert not bet.settledOrClosed, "Bet cloesd/settled"
    price: int256 = self.getPrice()
    winner: address = bet.maker
    pot: uint256 = bet.makerBet + bet.takerBet
    if not ((price > bet.price and bet.makerBetSide == 1) or (price < bet.price and bet.makerBetSide == 0)):
        winner = bet.taker
    self.bets[betId].settledOrClosed = True
    raw_call(winner, b'', value=pot)
    log betSettled(winner, pot, betId)
@external
def closeBet(betId: uint256):
    bet: BetData = self.bets[betId]
    assert not bet.settledOrClosed, "Bet closed/settled"
    assert bet.takerDeadline < block.timestamp, "Too early"
    assert bet.taker == empty(address), "Bet already accepted"
    self.bets[betId].settledOrClosed = True
    raw_call(bet.maker, b'', value=bet.makerBet)
    log betClosed(bet.maker, betId)


    
