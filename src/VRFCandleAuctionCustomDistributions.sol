// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@solmate/tokens/ERC721.sol";
import "@solmate/tokens/ERC20.sol";
import "@solmate/utils/ReentrancyGuard.sol";
import "@solmate/utils/SafeTransferLib.sol";
import "@solmate/auth/Owned.sol";
import "./interfaces/IVRFCandleAuctionErrors.sol";
import "./interfaces/IRandomNumberGenerator.sol";


contract VRFCandleAuctionCustomDistributions is IVRFCandleAuctionErrors, ReentrancyGuard, Owned {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                DATASTRUCTURES
    //////////////////////////////////////////////////////////////*/

    IRandomNumberGenerator randomGenerator;

    /// @notice Auction Struct
    /// @param tokenContract ERC721 token address
    /// @param tokenID ERC721 token id 
    /// @param seller Auction seller address
    /// @param startingBlock Block at which the auction begins
    /// @param noTerminationBiddingPeriod Number of blocks for which the bids are guaranteed to be accepted into the auction
    /// @param possibleTerminationPeriod Number of blocks after the no termination period where sudden termination is possible 
    /// @param highestBid The current highest bid
    /// @param auctionSettled An auction has ended an user's are now able to withdrawl funds
    /// @param blocksPerPeriod Number of blocks per probablity distribution period
    /// @param flipsPerPeriod Specified number of coin flips per period
    /// @dev possibleTerminationPeriod should be the product of flipsPerPeriod length and number of periods
    struct Auction {
        address tokenContract;
        uint256 tokenId;
        /*///////////////////*/
        address seller;
        /*///////////////////*/
        uint32 startingBlock;
        uint32 noTerminationBiddingPeriod;
        uint32 possibleTerminationPeriod;
        /*///////////////////*/
        uint256 highestBid;
        /*///////////////////*/
        bool auctionSettled;
        /*///////////////////*/
        uint32 blocksPerPeriod;
        uint32[] flipsPerPeriod;
    }

    /// @notice HighestBidder struct for a specified block
    /// @param blockNumber block number
    /// @param bidder highest bidder at this block
    /// @param bid bid of highest bidder at this block
    struct HighestBidder {
        uint32 blockNumber;
        address bidder;
        uint256 bid;
    }   

    /// @notice Internally used ID system to track auctions
    uint256 uid; 

    mapping(uint256 => Auction) public Auctions; 

    mapping(uint256 => mapping(address => uint256)) public Bids;

    mapping(uint256 => HighestBidder[]) public HighestBidPerPeriod;

   
    /*//////////////////////////////////////////////////////////////
                                 Errors
    //////////////////////////////////////////////////////////////*/
    
    error InvalidFlipsInitialization();

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
        uint256 reservePrice,
        uint256 uid,
        uint32 blocksPerPeriod,
        uint32[] flipsPerPeriod
    );

    event AuctionEnded (
        uint32 endBlock,
        address higestBidder,
        uint256 higestBid
    );

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(  address randomNumberGeneratorAddress ) Owned(msg.sender) {
        randomGenerator = IRandomNumberGenerator(randomNumberGeneratorAddress);
    }

    /// @notice Create an Auction
    /// @return UID returns a UID for the auction created
    function createAuction(
        address _tokenContract,
        uint256 _tokenId,
        uint32 _startingBlock,
        uint32 _noTerminationBiddingPeriod,
        uint32 _possibleTerminationBiddingPeriod,
        uint256 reservePrice,
        uint32 _blocksPerPeriod,
        uint32[] memory _flipsPerPeriod
    ) external nonReentrant returns (uint256) {
        
        // Require that possibleTerminationPeriod is the product of flipsPerPeriod length and number of blocks per period
        if (_flipsPerPeriod.length != _possibleTerminationBiddingPeriod / _blocksPerPeriod) {
            revert InvalidFlipsInitialization();
        }
        
        // Require that flipsPerPeriod is non-zero
        for (uint i =0; i < _flipsPerPeriod.length; i++) {
            if (_flipsPerPeriod[i] == 0) {
                revert InvalidFlipsInitialization();
            }
        }
        // Next UID
        uid++;

        Auction storage auction = Auctions[uid]; 
         // If no starting block is set, set at current block number
        if (_startingBlock == 0) {
            auction.startingBlock = uint32(block.number);
        // block number must be for the present or a future block
        } else if (_startingBlock < block.number) {
            revert InvalidStartTime(_startingBlock);
        } 

        // No termination period must be atleast 18000 blocks or ~ 60 minutes
        if (_noTerminationBiddingPeriod < 18000) {
            revert InvalidNoTerminationBiddingPeriod(_noTerminationBiddingPeriod);
        }

        // Possible termination period must be atleast 18000 blocks or ~ 60 minutes
        if (_possibleTerminationBiddingPeriod < 18000) {
            revert InvalidPossibleTerminationBiddingPeriod(_possibleTerminationBiddingPeriod);
        }

        // Intialize Auction Struct
        auction.tokenContract = _tokenContract; 
        auction.tokenId = _tokenId;
        auction.seller = msg.sender;
        auction.startingBlock = _startingBlock;
        auction.noTerminationBiddingPeriod = _noTerminationBiddingPeriod;
        auction.possibleTerminationPeriod = _possibleTerminationBiddingPeriod;
        auction.highestBid = reservePrice; 
        auction.auctionSettled = false;
        auction.blocksPerPeriod = _blocksPerPeriod;
        auction.flipsPerPeriod = _flipsPerPeriod;

        // Set auction seller as the default highest bidder
        HighestBidder[] storage highestBidder = HighestBidPerPeriod[uid];
        highestBidder.push(HighestBidder(uint32(block.number), msg.sender, reservePrice));
        
         // Send ERC721 to this address
        ERC721(auction.tokenContract).transferFrom(msg.sender, address(this), auction.tokenId);
        
        // Event Emit
        emit AuctionCreated(
            _tokenContract, 
            _tokenId,
            msg.sender, 
            _startingBlock,
            _noTerminationBiddingPeriod, 
            _possibleTerminationBiddingPeriod, 
            reservePrice, 
            uid, 
            _blocksPerPeriod,
            _flipsPerPeriod
            );
        
        return uid;
    }

    /// @notice Bid on an Auction
    /// @dev Any payment will check if a previous payment has already been made and raise the bid to the be the sum of past payments and the new bid
    /// @param _uid ID for a specific auction
    function bid(
        uint256 _uid
    ) external payable nonReentrant {
        // Check that UID is a valid id
        if (_uid == 0 || _uid > uid) {
            revert InvalidUID();
        }
       Auction storage auction = Auctions[_uid];

       uint256 currentBid = 0;
       // Checks for a previous bid
       if (Bids[_uid][msg.sender] != 0) {
            currentBid = Bids[_uid][msg.sender] + msg.value; 
       } else {
        currentBid = msg.value;
       }
        // A bid must take place during the specified auction period
       if (block.number > auction.startingBlock + auction.noTerminationBiddingPeriod +  auction.possibleTerminationPeriod) {
            revert InvalidBidTime();
       }
       // A bid must be greater than the previous highest bid
       if (currentBid <= auction.highestBid)  {
            revert BidTooLow(auction.highestBid);
       }
       auction.highestBid = msg.value;
    
        // Keeps track of a user's total amount bid
       if (Bids[_uid][msg.sender] != 0) {
            Bids[_uid][msg.sender] = Bids[_uid][msg.sender] + msg.value;
       } else {
            Bids[_uid][msg.sender] = msg.value;
       }

        // Updates the highest bid per block with the new bid
        HighestBidder[] storage highestBidder = HighestBidPerPeriod[_uid];

        if (highestBidder.length != 0 && highestBidder[highestBidder.length-1].blockNumber == block.number) {
           highestBidder[highestBidder.length-1].bidder = msg.sender;
           highestBidder[highestBidder.length-1].bid = msg.value; 
        } else {
            highestBidder.push(HighestBidder(uint32(block.number), msg.sender, msg.value));
        }
        // Emit Event
        emit HighestBid(msg.sender, msg.value);
    }

    /// @notice Ends Auctions and request a random number to determine the termination block
    /// @dev Can only be caused by the owner of this contract (platform owner) NOT the auction seller. 
    function endAuction(
        uint256 _uid
    ) public nonReentrant onlyOwner() {
        // Check that UID is a valid id
        if (_uid == 0 || _uid > uid) {
            revert InvalidUID();
        }
        Auction storage auction = Auctions[_uid];
        if (block.number <= (auction.startingBlock + auction.noTerminationBiddingPeriod + auction.possibleTerminationPeriod)) {
            revert InvalidAuctionInProccess();
        }

        randomGenerator.requestRandom();

    }

    /// @notice Settles Auctions and transfer ERC721 to the highest bidder
    /// @dev Can only be caused by the owner of this contract (platform owner) NOT the auction seller. 
    function settleAuction(
       uint256 _uid
    ) public nonReentrant onlyOwner() {
        // Check that UID is a valid id
        if (_uid == 0 || _uid > uid) {
            revert InvalidUID();
        }
         Auction storage auction = Auctions[_uid];
        // Check that the auction is over
        if (block.number <= (auction.startingBlock + auction.noTerminationBiddingPeriod + auction.possibleTerminationPeriod)) {
            revert InvalidAuctionInProccess();
        }

        uint256 randomNumber = randomGenerator.getRandom();

        uint32 blockIndexWithinPossibleTerminationPeriod = uint32(auction.flipsPerPeriod.length);
        for (uint32 index = 0; index < auction.flipsPerPeriod.length; index++) {
            uint256 mask = (1 << auction.flipsPerPeriod[index]) - 1;
            uint maskedResult = randomNumber & mask;

            if (maskedResult == mask) {
                blockIndexWithinPossibleTerminationPeriod = index;
                break;
            }
        }
       
        uint32 chosenEndBlock = auction.startingBlock + auction.noTerminationBiddingPeriod + (blockIndexWithinPossibleTerminationPeriod * auction.blocksPerPeriod);

        HighestBidder[] storage highestBidder = HighestBidPerPeriod[_uid];

        // Checks for the highest bid at the time the auction ended
        uint32  winningPeriodIndex;
        for (uint32 i = uint32(highestBidder.length -1); i >= 0; i--) {
            
            if (highestBidder[i].blockNumber < chosenEndBlock) {
                winningPeriodIndex = i;
                break;
            } 
        }

        address winningBidder = highestBidder[winningPeriodIndex].bidder;
        uint256 winningBid = highestBidder[winningPeriodIndex].bid;
        // Sets highest bidder bid to 0
        Bids[_uid][winningBidder] = 0;
        auction.auctionSettled = true;
        // Sends ERC721 to winning bidder
        ERC721(auction.tokenContract).transferFrom(address(this),  winningBidder, auction.tokenId);
         // Sends highest bid to the seller

        if (winningBidder != auction.seller) {
            auction.seller.safeTransferETH(winningBid);
        }
        // Emit Event
        emit AuctionEnded(highestBidder[winningPeriodIndex].blockNumber, winningBidder, highestBidder[winningPeriodIndex].bid);

    }

    /// @notice Allows losing bidders to withdrawl their bid
    /// @dev A bidder can only withdrawl their bid after an auction has been settled
    function withdrawlFunds(
        uint256 _uid 
    ) public nonReentrant {
        // Check that UID is a valid id
        if (_uid == 0 || _uid > uid) {
            revert InvalidUID();
        }
        Auction storage auction = Auctions[_uid];
        // Check that the auction is over
        if (block.number <= (auction.startingBlock + auction.noTerminationBiddingPeriod + auction.possibleTerminationPeriod)) {
            revert InvalidAuctionInProccess();
        }
         // Check that the auction has been settled
        if (auction.auctionSettled != true) {
            revert InvalidAuctionInProccess();
        }
        // Set Bid to 0
        uint256 amountToReturn = Bids[_uid][msg.sender];
        Bids[uid][msg.sender] = 0;

        msg.sender.safeTransferETH(amountToReturn);
        
    }

     

   
}