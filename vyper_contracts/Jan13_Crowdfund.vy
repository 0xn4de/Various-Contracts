

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
    r: FundRaise = self.raises[_raiseId]
    assert r.owner != empty(address), "Raise does not exist"
    assert r.goal >= self.raises[_raiseId].contributed+msg.value, "Raise over goal"
    assert r.deadline > block.timestamp, "Raise over"
    self.raises[_raiseId].contributed += msg.value
    self.contributors[msg.sender][_raiseId] += msg.value

@external
def withdraw(_raiseId: uint256):
    r: FundRaise = self.raises[_raiseId]
    assert not r.ended, "Raise finished"
    assert r.owner == msg.sender, "Not raise owner"
    assert r.goal <= r.contributed, "Raise did not meet its goal"
    self.raises[_raiseId].ended = True
    raw_call(msg.sender, b'', value=self.raises[_raiseId].contributed)

@external
def withdrawContribution(_raiseId: uint256):
    r: FundRaise = self.raises[_raiseId]
    assert r.deadline < block.timestamp, "Raise not over"
    assert r.contributed < self.raises[_raiseId].goal, "Raise met its goal"
    assert self.contributors[msg.sender][_raiseId] > 0, "Nothing to withdraw"
    withdrawAmount: uint256 = self.contributors[msg.sender][_raiseId]
    self.contributors[msg.sender][_raiseId] = 0
    raw_call(msg.sender, b'', value=withdrawAmount)
