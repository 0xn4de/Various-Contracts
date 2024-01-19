

struct FundRaise:
    ended: bool
    owner: address
    goal: uint256
    contributed: uint256
    deadline: uint256 

raiseId: public(uint256)

raises: public(HashMap[uint256, FundRaise])

contributors: public(HashMap[address, HashMap[uint256, uint256]])


@external
def createRaise(goal: uint256, raiseLength: uint256, owner: address) -> uint256:
    assert goal > 0 and raiseLength > 0, "Wrong inputs"
    self.raiseId += 1
    self.raises[self.raiseId] = FundRaise({ended: False, owner: owner, goal: goal, contributed: 0, deadline:block.timestamp+raiseLength})
    return self.raiseId

@external
@payable
def contribute(_raiseId: uint256):
    assert self.raises[_raiseId].owner != empty(address), "Raise does not exist"
    assert self.raises[_raiseId].goal >= self.raises[_raiseId].contributed+msg.value, "Raise over goal"
    assert self.raises[_raiseId].deadline > block.timestamp, "Raise over"
    self.raises[_raiseId].contributed += msg.value
    self.contributors[msg.sender][_raiseId] += msg.value

@external
def withdraw(_raiseId: uint256):
    assert not self.raises[_raiseId].ended, "Raise finished"
    assert self.raises[_raiseId].owner == msg.sender, "Not raise owner"
    assert self.raises[_raiseId].goal <= self.raises[_raiseId].contributed, "Raise did not meet its goal"
    self.raises[_raiseId].ended = True
    raw_call(msg.sender, b'', value=self.raises[_raiseId].contributed)

@external
def withdrawContribution(_raiseId: uint256):
    assert self.raises[_raiseId].deadline < block.timestamp, "Raise not over"
    assert self.raises[_raiseId].contributed < self.raises[_raiseId].goal, "Raise met its goal"
    assert self.contributors[msg.sender][_raiseId] > 0, "Nothing to withdraw"
    withdrawAmount: uint256 = self.contributors[msg.sender][_raiseId]
    self.contributors[msg.sender][_raiseId] = 0
    raw_call(msg.sender, b'', value=withdrawAmount)
