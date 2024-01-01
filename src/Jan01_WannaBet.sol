// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface AggregatorV3Interface {
    function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}
enum Side {
    UNDER, OVER
}
struct BetData {
    address taker;
    address maker;
    Side makerBetSide;
    uint256 makerBet;
    uint256 takerBet;
    uint256 ends; // Time the bet ends
    uint256 takerDeadline; // Time for someone to accept bet to prevent betting last second when you know price is in your favor
    int256 price; // ETH (or other) price * 1e8 (Chainlink decimals)
    bool settledOrClosed;
}
contract WannaBet {
    AggregatorV3Interface public immutable priceFeed;
    uint256 wagers = 0;
    mapping (uint256 => BetData) public bets;
    event betCreated(address indexed maker, int256 indexed price, uint256 indexed betId, uint256 ends, uint256 takerDeadline, uint256 takerBet, Side side);
    event betSettled(address indexed winner, uint256 indexed pot, uint256 indexed betId);
    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }
    function createBet(int256 price, Side side, uint256 ends, uint256 takerDeadline, uint256 takerBet) external payable returns (uint256 betId) {
        require(msg.value > 0, "No ETH Bet");
        require(ends > block.timestamp, "Bet end is in the past");
        ++wagers;
        bets[wagers] = BetData(address(0), msg.sender, side, msg.value, takerBet, ends, takerDeadline, price, false);
        emit betCreated(msg.sender, price, wagers, ends, takerDeadline, takerBet, side);
        return wagers;

    }
    function acceptBet(uint256 betId) external payable {
        BetData storage bet = bets[betId];
        require(bet.takerDeadline > block.timestamp, "Too late, bet closed");
        require(bet.taker == address(0), "Someone already bet");
        require(bet.takerBet == msg.value, "You bet too little/too much");
        bet.taker = msg.sender;
    }
    function settleBet(uint256 betId) external {
        BetData storage bet = bets[betId];
        require(bet.ends < block.timestamp, "Bet hasn't ended");
        require(!bet.settledOrClosed, "Bet closed/settled");
        int price = getPrice();
        address winner;
        uint256 pot = bet.makerBet + bet.takerBet;
        if ((price > bet.price && bet.makerBetSide == Side.OVER) || (price < bet.price && bet.makerBetSide == Side.UNDER) ) {
            winner = bet.maker;
        } else {
            winner = bet.taker;
        }
        bet.settledOrClosed = true;
        (bool success,) = payable(winner).call{value: pot}("");
        require(success, "Unsuccessful transfer");
        emit betSettled(winner, pot, betId);
    }
    function closeBet(uint256 betId) external {
        BetData storage bet = bets[betId];
        require(!bet.settledOrClosed, "Bet closed/settled");
        require(bet.takerDeadline < block.timestamp, "Too early");
        require(bet.taker == address(0), "Bet already accepted");
        uint256 amountToRefund = bet.makerBet;
        address maker = bet.maker;
        bet.settledOrClosed = true;
        (bool success,) = payable(maker).call{value: amountToRefund}("");
        require(success, "Unsuccessful transfer");
    }
    function getPrice() public view returns (int) {
        (,int price,,,) = priceFeed.latestRoundData();
        return price;
    }
}
