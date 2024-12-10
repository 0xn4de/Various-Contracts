# A Contract A Day

This will be a collection of smart contracts I aim to create nearly every day, provided I have enough time and ideas

Contracts are in src/, while the tests are in test/

I've also started adding Vyper versions of contracts (ran out of ideas), those are in vyper_contracts/ (s/o to [0xKitsune](https://github.com/0xKitsune/Foundry-Vyper))

Same tests work for both Vyper & Solidity (where possible) with small modifications, Vyper tests are in test/vyper_tests/

**If you have any ideas (desperately need some) or questions, please hit me up on** [Twitter](https://twitter.com/0xf4d3)!

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
- [NFTMarket](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan08_NFTMarket.sol)
  - Market for ERC721s, allows anyone to create a trade to swap ERC721<>ERC721
  - Allows setting a deadline timestamp for trades
  - Cancellable orders with `cancelTrade(id)`
  - Call `createTrade` with relevant data, incl. the tokenIds you want to sell (can't yet specify what ids you want to buy)
  - Accept trade with `acceptTrade(id, [idsYouWantToSellInReturn])`, will distribute assets accordingly
- [WannaBetV2](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan09_WannaBetV2.sol)
  - Similar to WannaBet (check first contract), slight difference, used in conjuction with WannaBetFactory
  - Added functionality of being able to wager tokens instead of just ETH
  - Bets can be token-token, token-eth, eth-token, eth-eth
  - Maker sets how much of what they are depositing and then sets how much they want the taker to deposit and of what currency (e.g. Bet that ETH is above 2500 on February 12th, 1000 USDT for your 0.4 ETH, if I win I get your ETH)
- [WannaBetFactory](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan10_WannaBetFactory.sol)
  - Factory contract for WannaBetV2 contracts
  - `deploy(base, quote)` takes in e.g. ETH & USD addresses (as per Chainlink definitions) and deploys a WannaBet contract for said pool
  - Pool can be used for price wagers as set out in WannaBetV2 description
  - base and quote are needed instead of priceFeed because it's hard to verify (AFAIK) a legitimate Chainlink feed (perhaps with ENS names pointing to price feeds but unideal) and since the registry returns aggregator addresses instead of proxy addresses, they can't be called (for whatever reason) by an unauthorized address, making WannaBetV2 itself also rely on base and quote
- [NFTAuction](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan11_NFTAuction.sol)
  - Basic auction contract for ERC721 and [ERC6909](https://eips.ethereum.org/EIPS/eip-6909), allows a seller to put an NFT on auction and set a reserve, minimum raise and a buy now price, in ETH
  - If the value sent with `bid` exceeds buyNow, auction gets settled immediately
  - If the auction does not meet the reserve, bid and NFT gets returned
  - This contract is **_severely undertested_** and is far from a perfect implementation, hence subject to multiple attack vectors
- [Locker](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan12_Locker.sol)
  - Basic vesting contract for ERC20 & ETH
  - Call `deposit` with relevant data (token (0x0 for eth), amount, vestingLength, beneficiary)
  - Beneficiary can withdraw once vesting has ended
  - Beneficiary can change the beneficiary using `changeBeneficiary`
- [Crowdfund](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan13_Crowdfund.sol)
  - Basic crowdfunding contract for ETH
  - Calling `createRaise(goal, length, owner)` will create a raise with a set goal and deadline
  - People can contribute by calling `contribute(raiseId)`
  - If goal is met, owner can withdraw, if not, contributors can withdraw (after deadline)
- [Prediction](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan14_Prediction.sol)
  - A **very** basic implementation of an idea inspired by [horsefacts](https://twitter.com/eth_call/status/1609463639399956482)
  - Call `createPrediction(keccak256("This is my prediction for 2024"))` to save prediction
  - Call `revealPrediction(predId, "This is my prediction for 2024")` to reveal prediction
- [LockerToken](https://github.com/0xn4de/A-Contract-A-Day/blob/main/src/Jan31_LockerToken.sol)
  - Nearly identical in behaviour to Locker
  - Difference is that beneficiary is tracked through ownership of an ERC721 id that corresponds to the vesting data
  - Transfer the ERC721 to another address to change beneficiary
  - Token gets minted on deposit, burned on withdraw
- [Contest](./src/Contest.sol)
  - Modeled (slightly) after [this problem](https://twitter.com/CleanPegasus/status/1805634062356242619)
  - Contract starts with a blockDifference and a minBid
  - Every player will put in a minBid and become the last caller, at the block number in which they called
  - After blockDifference amount of blocks, the last caller can withdraw the contract's balance
  - Game (should) be able to be continued in perpetuity, e.g. after `end()` is called a new person can call `bid()`

</details>

## Testing
You may have to [install Vyper](https://docs.vyperlang.org/en/v0.2.12/installing-vyper.html) (0.3.7)

Add an Ethereum RPC URL to .env

```shell
forge test --match-path test/{ContractGoesHere}.t.sol  -vv
```
