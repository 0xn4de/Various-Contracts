pragma solidity ^0.8.0;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract Crowdfund {

    struct Raise {
        bool ended;
        address owner;
        uint256 goal;
        uint256 contributed;
        uint256 deadline;
    }

    mapping(uint256 => Raise) raises;
    mapping(address => mapping(uint256 => uint256)) contributors;

    event RaiseCreated(uint256 indexed goal, uint256 indexed raiseLength, address indexed owner);
    event Contributed(address indexed contributor, uint256 indexed amount, uint256 indexed raiseId);
    event WithdrawRaise(uint256 indexed raiseId, uint256 indexed amount, address indexed to);
    event WithdrawContribution(uint256 indexed raiseId, uint256 indexed amount, address indexed to);

    uint256 raiseId;

    function createRaise(uint256 goal, uint256 raiseLength, address owner) external returns (uint256) {
        require(goal > 0 && raiseLength > 0, "Wrong inputs");
        raiseId++;
        raises[raiseId] = Raise(false, owner, goal, 0, block.timestamp+raiseLength);
        emit RaiseCreated(goal, raiseLength, owner);
        return raiseId;
    }

    function contribute(uint256 _raiseId) external payable {
        require(raises[_raiseId].owner != address(0), "Raise does not exist");
        require(raises[_raiseId].goal >= raises[_raiseId].contributed+msg.value, "Raise over goal");
        require(raises[_raiseId].deadline > block.timestamp, "Raise over");
        raises[_raiseId].contributed += msg.value;
        contributors[msg.sender][_raiseId] += msg.value;
        emit Contributed(msg.sender, msg.value, _raiseId);
    }
    function withdraw(uint256 _raiseId) external {
        require(!raises[_raiseId].ended, "Raise finished");
        require(raises[_raiseId].owner == msg.sender, "Not raise owner");
        require(raises[_raiseId].goal <= raises[_raiseId].contributed, "Raise did not meet its goal");
        raises[_raiseId].ended = true;
        SafeTransferLib.safeTransferETH(raises[_raiseId].owner, raises[_raiseId].contributed);
        emit WithdrawRaise(_raiseId, raises[_raiseId].contributed, msg.sender);
    }
    function withdrawContribution(uint256 _raiseId) external {
        require(raises[_raiseId].deadline < block.timestamp, "Raise not over");
        require(raises[_raiseId].goal > raises[_raiseId].contributed, "Raise met its goal");
        require(contributors[msg.sender][_raiseId] > 0, "Nothing to withdraw");
        uint256 withdrawAmount = contributors[msg.sender][_raiseId];
        contributors[msg.sender][_raiseId] = 0;
        SafeTransferLib.safeTransferETH(msg.sender, withdrawAmount);
        emit WithdrawContribution(_raiseId, raises[_raiseId].contributed, msg.sender);
    }
}