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
- [FreeForAllToken](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan04_FreeForAllToken.sol)
  - ERC20 built on [Solmate's ERC20](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol) where you can take others tokens during a 1-hour period every single day, similar to FreeForAll.sol
  - Every 24 hours, `transferFrom` is allowed to be called (**for 1 hour**) by anyone for anyone's tokens
  - startTime is at the same time every day, but if no transfers happen in the 23 hours beforehand, `transferFrom` will need to be called (with a legitimate transfer)
- [FreeForAll1155](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan05_FreeForAll1155.sol)
  - ERC1155 built on [Solmate's ERC1155](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol) where you can take others tokens during a 1-hour period every single day, (basically) identical to FreeForAll.sol
- [ERC1155Vault](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan06_ERC1155Vault.sol)
  - An ERC4626-like MultiVault that allows you to create a vault that accepts a certain tokenId of an ERC1155 and will give you an ERC1155 of specific tokenId in return
  - Base from [z0r0z's](https://twitter.com/z0r0zzz) [MultiVault](https://github.com/z0r0z/MultiVault/) which allows you to deposit an ERC20 and get an ERC1155 in return
  - How it works:
    - `create(erc1155, tokenid)` will allow you to create a vault for a specific ERC1155 contract's tokenId, e.g. a vault for `tokenId` 5 from a random ERC1155
    - Allows you to deposit any amount of that specific tokenId and then gives you an ERC1155 with a tokenId that is used only for that specific tokenId
    - Redeem your given ERC1155 and get your original NFT with tokenId 5 back
  - Undertested, exercise caution
- [Market](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan07_Market.sol)
  - Market for ERC20s and ETH, allows anyone to create a trade where they set out how much of what they want to buy and how much of what they give in return
  - Allows setting a deadline timestamp for trades
  - Cancellable orders with `cancelTrade(id)`
  - Call `createTrade` with relevant data (zero address for ETH asset)
  - Accept trade with `acceptTrade(id)`, will distribute assets accordingly

</details>

## Testing

Add an Ethereum RPC URL to .env

```shell
forge test --match-path test/{ContractGoesHere}.t.sol  -vv
```
