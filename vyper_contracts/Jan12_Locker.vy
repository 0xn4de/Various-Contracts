

from vyper.interfaces import ERC20

struct VestingInfo:
    token: address
    amount: uint256
    vestingEndTime: uint256
    beneficiary: address
    withdrawn: bool

vestingData: public(HashMap[uint256, VestingInfo])

vestingId: public(uint256)

event Deposit:
    vestingId: indexed(uint256)
    token: address
    amount: uint256
    vestingEndTime: uint256
    beneficiary: indexed(address)
event Withdraw:
    vestingId: indexed(uint256)
    token: address
    amount: uint256
    beneficiary: indexed(address)

@external
@payable
def deposit(_token: address, _amount: uint256, _vestingDuration: uint256, _beneficiary: address) -> uint256:
    assert _amount > 0 and _vestingDuration > 0, "Invalid deposit"
    vestingEndTime: uint256 = block.timestamp + _vestingDuration
    self.vestingId += 1
    if _token == empty(address):
        assert msg.value == _amount, "Wrong value sent"
    else:
        ERC20(_token).transferFrom(msg.sender, self, _amount)
    
    self.vestingData[self.vestingId] = VestingInfo({token: _token, amount: _amount, vestingEndTime: vestingEndTime, beneficiary: _beneficiary, withdrawn:False})
    log Deposit(self.vestingId, _token, _amount, vestingEndTime, _beneficiary)
    return self.vestingId

@external
def changeBeneficiary(_vestingId: uint256, _newBeneficiary: address):
    assert msg.sender == self.vestingData[_vestingId].beneficiary, "Not the beneficiary"
    self.vestingData[_vestingId].beneficiary = _newBeneficiary

@external
def withdraw(_vestingId: uint256):
    assert msg.sender == self.vestingData[_vestingId].beneficiary, "Not the beneficiary"
    assert not self.vestingData[_vestingId].withdrawn, "Already withdrawn"
    assert block.timestamp >= self.vestingData[_vestingId].vestingEndTime, "Vesting period not over"
    
    self.vestingData[_vestingId].withdrawn = True
    
    token: address = self.vestingData[_vestingId].token
    withdrawAmount: uint256 = self.vestingData[_vestingId].amount
    self.vestingData[_vestingId].amount = 0

    if token == empty(address):
        raw_call(msg.sender, b'', value=withdrawAmount)
    else:
        ERC20(self.vestingData[_vestingId].token).transfer(msg.sender, withdrawAmount)
    log Withdraw(_vestingId, self.vestingData[_vestingId].token, self.vestingData[_vestingId].amount, msg.sender)


