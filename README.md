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
- [BullToken](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan02_BullToken.sol)
  - ERC20 built on [Solmate's ERC20](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol) where transfers can only happen when ETH (or other) price is up since last update (weekly, automatic on transfer)
  - Contract gets deployed with ETH as the feed, constructor checks current price and sets it in the contract (minPrice) along with last updated time (lastUpdated)
  - When transfers happen, the **current** price (per Chainlink) has to be above the minPrice
  - If a week has passed since `lastUpdated` was updated, contract fetches a new price during a transfer call and updates the data
- [FreeForAll](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan03_FreeForAll.sol)
  - ERC721 built on [Solmate's ERC721](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol) where you can take others NFT's during a 1-hour period every single day
  - Every 24 hours, `transferFrom` is allowed to be called (**for 1 hour**) by anyone for anyone's tokenId
  - startTime is at the same time every day, but if no transfers happen in the 23 hours beforehand, `transferFrom` will need to be called (with a legitimate transfer)

</details>

## Testing

Add an Ethereum RPC URL to .env

```shell
forge test --match-path test/{ContractGoesHere}.t.sol  -vv
```
