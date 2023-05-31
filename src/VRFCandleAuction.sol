// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@solmate/tokens/ERC721.sol";
import "@solmate/tokens/ERC20.sol";
import "@solmate/utils/ReentrancyGuard.sol";
import "@solmate/utils/SafeTransferLib.sol";
import "./IVRFCandleAuctionErrors.sol";

contract VRFCandleAuction is IVRFCandleAuctionErrors, ReentrancyGuard{
    using SafeTransferLib for address;



    
    address LINK_ADDRESS; 

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param Documents a parameter just like in doxygen (must be followed by parameter name)
    struct Auction {
        address seller;
        /*///////////////////*/
        uint32 startingBlock;
        uint32 noTerminationBiddingPeriod;
        uint32 possibleTerminationPeriod;
        /*///////////////////*/
        uint256 highestBid;
        /*///////////////////*/
        uint32 index; 
    }

    struct HighestBidder {
        uint32 blockNumber;
        address bidder;
        uint256 bid;
    }

    mapping(address => mapping(uint256 => Auction)) public Auctions;
    
    mapping(address => // ERC721
        mapping(uint256 => // TokenId
            mapping(uint32 => //  AuctionIndex
                mapping(address =>  // Bidder
                    uint256 // Bids
    )))) public Bids;

     mapping(address => // ERC721
        mapping(uint256 => // TokenId
            mapping(uint32 => //  AuctionIndex 
                    HighestBidder[]
    ))) public HighestBidPerPeriod;
    
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event HighestBid (
        address highestBidder,
        uint256 highestBid
    );

    event AuctionCreated (
        address tokenContract, 
        uint256 tokenId,
        address seller,
        uint32 startingBlock,
        uint32 noTerminationBiddingPeriod,
        uint32 possibleTerminationPeriod,
        uint256 reservePrice
    );

    event AuctionEnded (
        uint32 endBlock,
        address higestBidder,
        uint256 higestBid
    );



    constructor(address _LINK_ADDRESS ) {
        LINK_ADDRESS = LINK_ADDRESS;
    }

    function createAuction(
        address tokenContract,
        uint256 tokenId,
        uint32 _startingBlock,
        uint32 _noTerminationBiddingPeriod,
        uint32 _possibleTerminationBiddingPeriod,
        uint256 reservePrice
    ) public nonReentrant {

        Auction storage auction = Auctions[tokenContract][tokenId]; 
        // Error handling
        if (_startingBlock == 0) {
            auction.startingBlock = uint32(block.number);
        } else if (_startingBlock < block.number) {
            revert InvalidStartTime(_startingBlock);
        } 

        /// Approximately 5 mins
        if (_noTerminationBiddingPeriod < 25) {
            revert InvalidNoTerminationBiddingPeriod(_noTerminationBiddingPeriod);
        }

        /// Approximately 15 mins 
        if (_possibleTerminationBiddingPeriod < 75) {
            revert InvalidPossibleTerminationBiddingPeriod(_possibleTerminationBiddingPeriod);
        }

        if (auction.index != 0  
        && auction.startingBlock + auction.noTerminationBiddingPeriod + auction.possibleTerminationPeriod >= block.number
        ) {
            revert InvalidAuctionInProccess();
        }

        auction.seller = msg.sender;
        auction.startingBlock = _startingBlock;
        auction.noTerminationBiddingPeriod = _noTerminationBiddingPeriod;
        auction.possibleTerminationPeriod = _possibleTerminationBiddingPeriod;
        auction.highestBid = reservePrice; 
        auction.index = auction.index + 1;

        HighestBidder[] storage highestBidder = HighestBidPerPeriod[tokenContract][tokenId][auction.index];
        highestBidder.push(HighestBidder(uint32(block.number), msg.sender, reservePrice));
        

         // Sepolia LINK Address
        //address LINK_TOKEN_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

        ERC721(tokenContract).transferFrom(msg.sender, address(this), tokenId);
        
        
        // Event Emit
        emit AuctionCreated(tokenContract, tokenId, msg.sender, _startingBlock, _noTerminationBiddingPeriod, _possibleTerminationBiddingPeriod, reservePrice);
        
    }

    function bid(
        address tokenContract,
        uint256 tokenId,
        uint32 auctionIndex
    ) public payable nonReentrant {

       Auction storage auction = Auctions[tokenContract][tokenId];

       if (block.number > auction.startingBlock + auction.noTerminationBiddingPeriod +  auction.possibleTerminationPeriod) {
            revert InvalidBidTime();
       }
       if (msg.value <= auction.highestBid)  {
            revert BidTooLow(auction.highestBid);
       }

       auction.highestBid = msg.value;
       
       if (Bids[tokenContract][tokenId][auctionIndex][msg.sender] != 0) {
            Bids[tokenContract][tokenId][auctionIndex][msg.sender] = Bids[tokenContract][tokenId][auctionIndex][msg.sender] + msg.value;
       } else {
            Bids[tokenContract][tokenId][auctionIndex][msg.sender] = msg.value;
       }

        HighestBidder[] storage highestBidder = HighestBidPerPeriod[tokenContract][tokenId][auctionIndex];

        if (highestBidder.length != 0 && highestBidder[highestBidder.length-1].blockNumber == block.number) {
           highestBidder[highestBidder.length-1].bidder = msg.sender;
           highestBidder[highestBidder.length-1].bid = msg.value; 
        } else {
            highestBidder.push(HighestBidder(uint32(block.number), msg.sender, msg.value));
        }
        

        emit HighestBid(msg.sender, msg.value);

    }

    function endAuction(
        address tokenContract, 
        uint256 tokenId, 
        uint32 auctionIndex
    ) public nonReentrant {

        Auction storage auction = Auctions[tokenContract][tokenId];

        // FIXME MAKE ME RANDOM!!!
        uint32 chosenEndBlock = auction.startingBlock + auction.noTerminationBiddingPeriod + 50;

        if (block.number <= (auction.startingBlock + auction.noTerminationBiddingPeriod + auction.possibleTerminationPeriod)) {
            revert InvalidAuctionInProccess();
        }

        HighestBidder[] storage highestBidder = HighestBidPerPeriod[tokenContract][tokenId][auctionIndex];


        uint32  winningPeriodIndex;
        for (uint32 i = uint32(highestBidder.length -1); i >= 0; i--) {
            
            if (highestBidder[i].blockNumber < chosenEndBlock) {
                winningPeriodIndex = i;
                 break;
            } 
           
        }

        address winningBidder = highestBidder[winningPeriodIndex].bidder;
        Bids[tokenContract][tokenId][auctionIndex][winningBidder] = 0;

        ERC721(tokenContract).transferFrom(address(this),  winningBidder, tokenId);

        emit AuctionEnded(highestBidder[winningPeriodIndex].blockNumber, winningBidder, highestBidder[winningPeriodIndex].bid);

        // Don't allow it to call just once but forces it to always read the random value tied to the index of the auction. 
        // Revert if that index is not found.


    }

    function withdrawlFunds(
        address tokenContract, 
        uint256 tokenId, 
        uint32 auctionIndex
    ) public nonReentrant {
        Auction storage auction = Auctions[tokenContract][tokenId];

        if (block.number <= (auction.startingBlock + auction.noTerminationBiddingPeriod + auction.possibleTerminationPeriod)) {
            revert InvalidAuctionInProccess();
        }

        uint256 amountToReturn = Bids[tokenContract][tokenId][auctionIndex][msg.sender];
        Bids[tokenContract][tokenId][auctionIndex][msg.sender] = 0;

        msg.sender.safeTransferETH(amountToReturn);
        
    }

    // function withdrawlLINK(
    //     address tokenContract, 
    //     uint256 tokenId, 
    //     uint32 auctionIndex
    // ) public nonReentrant {
    //      // Sepolia LINK Address
    //     address LINK_TOKEN_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    //     Auction storage auction = Auctions[tokenContract][tokenId];

    //     if (msg.sender != auction.seller) {
    //         revert InvalidSeller();
    //     }

    //     uint256 amountToSend = remainingLINK[tokenContract][tokenId][auctionIndex];
    //     remainingLINK[tokenContract][tokenId][auctionIndex] = 0;

    //     ERC20(LINK_TOKEN_ADDRESS).transferFrom(address(this), msg.sender, amountToSend);

    // }
}