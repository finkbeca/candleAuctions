# Candle Auction

Sudden Termination (or Candle) is a solidity implementation of a single-item (ERC-721) auction, utilizing Chainlink's VRFv2 and bids in ETH. This design not only provides a level of resistance against front-running (the exact end block is unknown until the completion of the auction), but also supports early price discovery. Moreover, the contract is designed to accommodate a range of termination distributions, including uniform distribution (where the end block is chosen uniformly at random from the set of possible termination blocks) and custom distributions based on coin flips (which can make an auction more or less likely to end within a certain segment of the termination period). The end time is calculated retroactively using Chainlink's VRFv2 as a source of randomness. In the uniform model, this randomness is directly used to determine the end block, while in custom distributions, it is used to simulate coin flips over discrete periods to determine the end block.



## Inspiration
---
- https://onlinelibrary.wiley.com/doi/epdf/10.1111/j.1530-9134.2012.00329.x (Introduces Candle Auctions in the online setting utilizing a RNG)
- https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3846363 (Introduces Candle Auctions in the Blockchain system )

## How it works
---
- Platform owner initializes contract and subscribes to Chainlink's VRF
- A seller sets a start and end time, an initial number of blocks where termination is not allowed, the number of blocks for the termination period, the reserve price, and in the case of a custom distribution the number of discrete periods within the termination period and the desired distribution for each. The seller then sends their ERC=721 to the contract. 
- Starting from the start time, bidders can begin making bids on the ERC-721 (Note: multiple auctions are allowed to run concurrently). Bidding follows the common rules of an ascending auction, where each price must be higher than the previous price, and bidders are allowed to bid multiple times throughout the auction.
- After the end of the auction, the contract owner sends a request to Chainlink's VRF for randomness.
- The contract owner settles the auction, retrieving the randomness from the previous VRF request and using this to calculate the actual end block. Additionally, calculates the winning bidder and sends the ERC-721 to the winning bidder and their bid to the seller respectively. (Note if no bidders bid on an auction, the ERC-721 is returned to the seller at the end of the auction). 
- Losing bidders can now withdraw their bid from the platform. 

## How to run
---
Require Foundry.

Install: ``` forge install ```  
Build: ``` forge build ```   
Test: ``` forge test ```  

