# @version 0.4.0

lastCallBlock: public(uint256)
lastCaller: public(address)
startTime: public(immutable(uint32))
blockDifference: public(immutable(uint32))
minBid: public(immutable(uint256))


@deploy
def __init__(_startTime: uint32, _blockDifference: uint32, _minBid: uint256):
    startTime = _startTime
    blockDifference = _blockDifference
    minBid = _minBid


@external
@payable
def bid():
    assert block.timestamp >= convert(startTime, uint256), "Hasn't started" # "Cannot perform greater-or-equal between dislike types"
    assert msg.value == minBid, "Bid more"
    self.lastCaller = msg.sender
    self.lastCallBlock = block.number

@external
def end():
    assert block.number-self.lastCallBlock >= convert(blockDifference, uint256), "Wait a little more"
    assert self.lastCaller != empty(address), "You have to bid first"
    raw_call(self.lastCaller, b'', value=self.balance)
