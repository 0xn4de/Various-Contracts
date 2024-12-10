pragma solidity ^0.8.0;

contract Contest {

    uint256 public lastCallBlock;
    address public lastCaller;
    uint32 immutable startTime;
    uint32 immutable blockDifference;
    uint256 immutable minBid;


    constructor(uint32 _startTime, uint32 _blockDifference, uint256 _minBid) {
        startTime = _startTime;
        blockDifference = _blockDifference;
        minBid = _minBid;
    }

    function bid() external payable {
        require(block.timestamp >= startTime, "Hasn't started");
        require(msg.value == minBid, "Bid more");
        lastCaller = msg.sender;
        lastCallBlock = block.number;
    }

    function end() external {
        require(block.number-lastCallBlock >= blockDifference, "Wait a little more");
        require(lastCaller != address(0), "You have to bid first"); // ensures there's an actual winner
        lastCaller.call{value: address(this).balance}("");
    }
}