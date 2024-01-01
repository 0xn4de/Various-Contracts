# A Contract A Day

This will be a collection of smart contracts I aim to create nearly every day, provided I have enough time and ideas

Contracts are in src/, while the tests are in test/

**If you have any ideas or questions, please hit me up on** [Twitter](https://twitter.com/0xf4d3)!

This repository uses [Foundry](https://book.getfoundry.sh/)
# Contracts

<details>
<summary><b>January</b></summary>


- [WannaBet](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan01_WannaBet.sol)
    - Contract where you can set a Chainlink Price Feed address, then anyone can create a bet that takes the Over/Under on a given price point and allows anyone to accept the bet:
    - Bob wants to bet that ETH price is 2% higher in a month, he calls `createBet` with variables like price, if he's taking over/under, what odds hes giving himself (e.g. 1 ETH bet for 0.2 ETH on taker's side), settle time, time given for anyone to accept
    - If nobody accepts bet, he can withdraw after the time he set for someone to accept
    - If accepted, once the time is up, anyone can call `settleBet` and the contract checks Chainlink for the current price and sends funds accordingly

</details>



## Testing
Add an Ethereum RPC URL to .env

```shell
forge test --match-path test/{ContractGoesHere}.sol  -vv
```
