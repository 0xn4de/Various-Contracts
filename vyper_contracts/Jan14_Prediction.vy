

predId: public(uint256)

struct Pred:
    isRevealed: bool
    maker: address
    hash: bytes32
    pred: String[1000]

predictions: public(HashMap[uint256, Pred])
event PredictionCreated:
    maker: indexed(address)
    hash: indexed(bytes32)
    predId: uint256
event PredictionRevealed:
    maker: indexed(address)
    hash: indexed(bytes32)
    predId: indexed(uint256)
    prediction: String[1000]
@external
def createPrediction(_hash: bytes32) -> uint256:
    self.predId += 1
    self.predictions[self.predId] = Pred({isRevealed: False, maker: msg.sender, hash: _hash, pred: ""})
    log PredictionCreated(msg.sender, _hash, self.predId)
    return self.predId

@external
def revealPrediction(_predId: uint256, prediction: String[1000]) -> bool:
    p: Pred = self.predictions[_predId]
    assert p.pred == "", "Prediction already set"
    assert prediction != "", "Empty prediction"
    assert p.hash == keccak256(prediction), "Wrong reveal"
    self.predictions[_predId].pred = prediction
    log PredictionRevealed(self.predictions[_predId].maker, self.predictions[_predId].hash, _predId, prediction)
    return True