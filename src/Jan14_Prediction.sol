pragma solidity ^0.8.0;


contract Prediction {
    struct Pred {
        bool isRevealed;
        address maker;
        bytes32 hash;
        string pred;
    }
    mapping (uint256 => Pred) predictions;
    uint256 predId;
    event PredictionCreated(address indexed maker, bytes32 indexed hash, uint256 predId);
    event PredictionRevealed(address indexed maker, bytes32 indexed hash, uint256 indexed predId, string prediction);
    function createPrediction(bytes32 hash) external returns (uint256) {
        predId++;
        predictions[predId] = Pred(false, msg.sender, hash, "");
        emit PredictionCreated(msg.sender, hash, predId);
        return predId;
    }
    function revealPrediction(uint256 _predId, string memory prediction) external returns (bool) {
        Pred storage p = predictions[_predId];
        require(keccak256(abi.encodePacked(p.pred)) == keccak256(abi.encodePacked("")), "Prediction already set");
        require(keccak256(abi.encodePacked(prediction)) != keccak256(abi.encodePacked("")), "Empty prediction");
        require(p.hash == keccak256(bytes(prediction)), "Wrong reveal");
        p.pred = prediction;
        emit PredictionRevealed(p.maker, p.hash, _predId, prediction);
        return true;
    }
}