pragma solidity ^0.8.13;

interface IVRFCandleAuctionErrors {
    error InvalidBidTime();
    error InvalidAuctionInProccess();
    error BidTooLow(uint256 previousHighestBid);
    error InvalidSeller();
    error InvalidStartTime(uint32 startTime);
    error InvalidNoTerminationBiddingPeriod(uint32 biddingPeriod);
    error InvalidPossibleTerminationBiddingPeriod(uint32 biddingPeriod);
}