// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
enum Side {
    UNDER, OVER
}
struct BetTokenData {
    address makerAsset;
    uint256 makerBet;
    address takerAsset;
    uint256 takerBet;
}
struct BetData {
    bool settledOrClosed;
    address taker;
    address maker;
    Side makerBetSide;
    BetTokenData tokenData;
    uint256 ends; // Time the bet ends
    uint256 takerDeadline; // Time for someone to accept bet to prevent betting last second when you know price is in your favor
    int256 price; // ETH (or other) price * 1e8 (Chainlink decimals)
}
contract WannaBetV2 {
    using SafeTransferLib for ERC20;

    FeedRegistryInterface public immutable registry;
    address public immutable base;
    address public immutable quote;


    uint256 wagers = 0;

    mapping (uint256 => BetData) public bets;

    event betCreated(address indexed maker, int256 indexed price, uint256 indexed betId, BetTokenData tokenData, uint256 ends, uint256 takerDeadline, Side side);
    event betSettled(address indexed winner, uint256 indexed betId, address token1, uint256 amount1, address token2, uint256 amount2);
    event betClosed(uint256 indexed betId, address indexed maker);
    event betAccepted(uint256 indexed betId, address indexed taker);
    
    constructor(address _base, address _quote, FeedRegistryInterface _registry) {
        registry = _registry;
        base = _base;
        quote = _quote;
    }

    function createBet(int256 price, Side side, BetTokenData calldata tokenData, uint256 ends, uint256 takerDeadline) external payable returns (uint256 betId) {
        require(ends > block.timestamp, "Bet end is in the past");
        require(takerDeadline > block.timestamp && takerDeadline < ends, "Taker deadline cannot be in the past nor after settling timestamp");
        ++wagers;
        if (tokenData.makerAsset == address(0)) {
            require(msg.value == tokenData.makerBet, "Incorrect ETH amount");
        } else {
            ERC20(tokenData.makerAsset).safeTransferFrom(msg.sender, address(this), tokenData.makerBet);
        }
        bets[wagers] = BetData(false, address(0), msg.sender, side, tokenData, ends, takerDeadline, price);
        emit betCreated(msg.sender, price, wagers, tokenData, ends, takerDeadline, side);
        return wagers;

    }
    function acceptBet(uint256 betId) external payable {
        BetData storage bet = bets[betId];
        require(bet.takerDeadline > block.timestamp, "Too late, bet closed");
        require(bet.taker == address(0), "Someone already bet");
        if (bet.tokenData.takerAsset == address(0)) {
            require(msg.value == bet.tokenData.takerBet, "Incorrect ETH amount");
        } else {
            ERC20(bet.tokenData.takerAsset).safeTransferFrom(msg.sender, address(this), bet.tokenData.takerBet);
        }
        bet.taker = msg.sender;
        emit betAccepted(betId, msg.sender);
    }
    function settleBet(uint256 betId) external {
        BetData storage bet = bets[betId];
        require(bet.ends < block.timestamp, "Bet has not ended");
        require(!bet.settledOrClosed, "Bet closed/settled");
        int price = getPrice();
        address winner;
        if ((price > bet.price && bet.makerBetSide == Side.OVER) || (price < bet.price && bet.makerBetSide == Side.UNDER) ) {
            winner = bet.maker;
        } else {
            winner = bet.taker;
        }
        bet.settledOrClosed = true;
        if (bet.tokenData.makerAsset == address(0) || bet.tokenData.takerAsset == address(0)) {
            if (bet.tokenData.makerAsset == address(0) && bet.tokenData.takerAsset != address(0)) { // ETH for ERC20
                ERC20(bet.tokenData.takerAsset).safeTransfer(winner, bet.tokenData.takerBet);
                SafeTransferLib.safeTransferETH(winner, bet.tokenData.makerBet);
            } else if (bet.tokenData.makerAsset != address(0) && bet.tokenData.takerAsset == address(0)) { // ERC20 for ETH
                ERC20(bet.tokenData.makerAsset).safeTransfer(winner, bet.tokenData.makerBet);
                SafeTransferLib.safeTransferETH(winner, bet.tokenData.takerBet);
            } else { // ETH-ETH
                SafeTransferLib.safeTransferETH(winner, bet.tokenData.makerBet+bet.tokenData.takerBet);
            }
        } else {
            ERC20(bet.tokenData.takerAsset).safeTransfer(winner, bet.tokenData.takerBet);
            ERC20(bet.tokenData.makerAsset).safeTransfer(winner, bet.tokenData.makerBet);
        }
        emit betSettled(winner, betId, bet.tokenData.makerAsset, bet.tokenData.makerBet, bet.tokenData.takerAsset, bet.tokenData.takerBet);
    }
    function closeBet(uint256 betId) external {
        BetData storage bet = bets[betId];
        require(!bet.settledOrClosed, "Bet closed/settled");
        require(bet.takerDeadline < block.timestamp, "Too early");
        require(bet.taker == address(0), "Bet already accepted");
        bet.settledOrClosed = true;
        if (bet.tokenData.makerAsset == address(0)) {
            SafeTransferLib.safeTransferETH(bet.maker, bet.tokenData.makerBet);
        } else {
            ERC20(bet.tokenData.makerAsset).safeTransfer(bet.maker, bet.tokenData.makerBet);
        }
        emit betClosed(betId, msg.sender);
    }
    function getPrice() public view returns (int) {
        (,int price,,,) = registry.latestRoundData(base, quote);
        return price;
    }
}
