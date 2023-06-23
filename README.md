# Candle Auction

Sudden Termination (or Candle ) single-item (ERC-721) Auction solidity implementation utilizing Chainlinks VRFv2 and bids in ETH.  This design not only provides a level of front-running resistance (the exact end block is unknown til the completion of the auction) but supports early price discovery. Moreover, the contract is designed to support a range of termination distributions: uniform (chose uniformly at random the end block from the set of possible termination blocks  ), custom distributions based on coin flips (supports ascending or descending distributions to make an auction more or less likely to end within a certain segment of the termination period). End time is calculated retroactively utilizing Chainlink's VRFv2 as a source of randomness. In the uniform model, we use this randomness directly to determine the end block, in custom distributions this source of randomness is used to simulate coin flips over discrete periods to determine end the end block. 



## Inspiration
---
- https://onlinelibrary.wiley.com/doi/epdf/10.1111/j.1530-9134.2012.00329.x (Introduces Candle Auctions in the online setting utilizing a RNG)
- https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3846363 (Introduces Candle Auctions in the Blockchain system )

## How it works
---
- Platform owner initializes contract and subscribes to Chainlink's VRF
- A seller sets a start and end time, an initial number of blocks where termination is not allowed, the number of blocks for the termination period, the reserve price, and in the case of a custom distribution the number of discrete periods within the termination period and the desired distribution for each. The seller then sends their ERC721 to the contract. 
- Beginning at the start time, bidders can begin making bids on the ERC721 (Note: multiple auctions are allowed to run concurrently). Bidding follows the common rules of an ascending auction with each price having to be higher than the previous price with bidders allowed to bid multiple times throughout the auction. 
- After the end of the auction, the contract owner sends a request to Chainlink's VRF for randomness. 
- The contract owner settles the auction, this calculates the actual end block, calculates the winning bidder and sends the ERC-721 to the winning bidder and their bid to the seller respectively. (Note if no bidders bid on an auction, the ERC-721 is returned to the seller at the end of the auction). 
- Losing bidders can now withdraw their bid from the platform. 

## How to run
---
Require Foundry.

Install: ``` forge install ```  
Build: ``` forge build ```   
Test: ``` forge test ```  

