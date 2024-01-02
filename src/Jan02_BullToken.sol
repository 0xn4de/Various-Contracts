// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract BullToken is ERC20 {

    int256 public minPrice;
    uint256 public lastUpdated;
    AggregatorV3Interface immutable priceFeed;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply,
        address _priceFeed
    ) ERC20(name, symbol, decimals) {
        _mint(msg.sender, initialSupply);
        priceFeed = AggregatorV3Interface(_priceFeed);
        minPrice = getPrice();
        lastUpdated = block.timestamp;
    }
    
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        balanceOf[msg.sender] -= amount;
        int256 price = getPrice();
        if (block.timestamp > lastUpdated + 7 days) {
            minPrice = price;
            lastUpdated = block.timestamp;
        }
        require(price >= minPrice, "Price is too low");


        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        int256 price = getPrice();
        if (block.timestamp > lastUpdated + 7 days) {
            minPrice = price;
            lastUpdated = block.timestamp;
        }
        require(price >= minPrice, "Price is too low");

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }
    function getPrice() public view returns (int) {
        (,int price,,,) = priceFeed.latestRoundData();
        return price;
    }
}