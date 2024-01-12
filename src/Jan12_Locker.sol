// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract Locker {
    using SafeTransferLib for ERC20;

    struct VestingInfo {
        address token;
        uint256 amount;
        uint256 vestingEndTime;
        address beneficiary;
        bool withdrawn;
    }

    mapping(uint256 => VestingInfo) public vestingData;
    uint256 public vestingId;

    event Deposit(uint256 indexed vestingId, address token, uint256 amount, uint256 vestingEndTime, address indexed beneficiary);
    event Withdraw(uint256 indexed vestingId, address token, uint256 amount, address indexed beneficiary);

    modifier onlyBeneficiary(uint256 _vestingId) {
        require(msg.sender == vestingData[_vestingId].beneficiary, "Not the beneficiary");
        _;
    }

    function deposit(address _token, uint256 _amount, uint256 _vestingDuration, address _beneficiary) external payable returns (uint256) {
        require(_amount > 0 && _vestingDuration > 0, "Invalid deposit");

        uint256 vestingEndTime = block.timestamp + _vestingDuration;
        vestingId++;
        if (_token == address(0)) {
            require(msg.value == _amount, "Wrong value sent");
        } else {
            ERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }

        vestingData[vestingId] = VestingInfo(_token, _amount, vestingEndTime, _beneficiary, false);

        emit Deposit(vestingId, _token, _amount, vestingEndTime, _beneficiary);
        return vestingId;
    }
    function changeBeneficiary(uint256 _vestingId, address _newBeneficiary) external onlyBeneficiary(_vestingId) {
        vestingData[_vestingId].beneficiary = _newBeneficiary;
    }

    function withdraw(uint256 _vestingId) external onlyBeneficiary(_vestingId) {
        require(!vestingData[_vestingId].withdrawn, "Already withdrawn");
        require(block.timestamp >= vestingData[_vestingId].vestingEndTime, "Vesting period not over");

        vestingData[_vestingId].withdrawn = true;
        address token = vestingData[_vestingId].token;
        if (token == address(0)) {
            SafeTransferLib.safeTransferETH(msg.sender, vestingData[_vestingId].amount);
        } else {
            ERC20(vestingData[_vestingId].token).safeTransfer(msg.sender, vestingData[_vestingId].amount);
        }
        emit Withdraw(_vestingId, vestingData[_vestingId].token, vestingData[_vestingId].amount, msg.sender);
    }
}
