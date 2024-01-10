// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {WannaBetV2} from "./Jan09_WannaBetV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";

contract WannaBetFactory {

    FeedRegistryInterface immutable feedRegistry;

    mapping(address => mapping(address => address)) public pools;

    event poolDeployed(address indexed priceFeed);
    constructor (address _feedRegistry) {
        feedRegistry = FeedRegistryInterface(_feedRegistry);
    }
    function deploy(address base, address quote) public returns (address) {
        feedRegistry.getFeed(base, quote); // will revert if feed doesn't exist
        address pool = address(new WannaBetV2(base, quote, feedRegistry));
        pools[base][quote] = pool;

        return pool;
    }
}