// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract FreeForAllToken is ERC20 {

    uint256 public startTime;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply
    ) ERC20(name, symbol, decimals) {
        _mint(msg.sender, initialSupply);
        startTime = block.timestamp + 1 days;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        if (block.timestamp < startTime + 1 hours && block.timestamp > startTime) {
            balanceOf[from] -= amount;

            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value.
            unchecked {
                balanceOf[to] += amount;
            }

            emit Transfer(from, to, amount);
            return true;
        } else {
            if (block.timestamp > startTime + 1 hours) {
                startTime += 1 days;
            }
            return super.transferFrom(from, to, amount);
        }
    }
}