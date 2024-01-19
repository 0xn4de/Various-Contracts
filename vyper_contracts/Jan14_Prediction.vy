

predId: public(uint256)

struct Pred:
    isRevealed: bool
    maker: address
    hash: bytes32
    pred: String[1000]

predictions: public(HashMap[uint256, Pred])


@external
def createPrediction(_hash: bytes32) -> uint256:
    self.predId += 1
    self.predictions[self.predId] = Pred({isRevealed: False, maker: msg.sender, hash: _hash, pred: ""})
    return self.predId

@external
def revealPrediction(_predId: uint256, prediction: String[100]) -> bool:
    p: Pred = self.predictions[_predId]
    assert p.pred == "", "Prediction already set"
    assert prediction != "", "Empty prediction"
    assert p.hash == keccak256(prediction), "Wrong reveal"
    self.predictions[_predId].pred = prediction
    return True