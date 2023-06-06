// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//import "forge-std/Test.sol";
import "../src/VRFCandleAuctionCustomDistributions.sol";
import "../src/interfaces/IVRFCandleAuctionErrors.sol";
import "../src/interfaces/IRandomNumberGenerator.sol";
import "../src/RandomNumberGenerator.sol";
import "./mocks/LinkToken.sol";
import "./mocks/MockVRFCoordinatorV2.sol";
import "./utils/TestActors.sol";
import "./utils/TestERC721.sol";


contract VRFCandleAuctionCustomDistributionsTest is IVRFCandleAuctionErrors, TestActors {
    
    LinkToken public linkToken;
    MockVRFCoordinatorV2 public vrfCoordinator;
    VRFCandleAuctionCustomDistributions public candleAuction;
    RandomNumberGenerator public randomGenerator;
    TestERC721 public erc721;
    

     // Initialized as blank, fine for testing
    uint64 subId;
    bytes32 keyHash; // gasLane

    
    function setUp() public override {
        
        erc721 = new TestERC721();
        linkToken = new LinkToken();
        vrfCoordinator = new MockVRFCoordinatorV2();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1 ether);


       hoax(jim);
        randomGenerator = new RandomNumberGenerator(
            subId,
            address(vrfCoordinator),
            address(linkToken),
            keyHash
        );
        hoax(jim);
        candleAuction = new VRFCandleAuctionCustomDistributions(
            address(randomGenerator)
        );

        hoax(jim);
        randomGenerator.setConsumerContract(address(candleAuction));

        vrfCoordinator.addConsumer(subId, address(randomGenerator));
        
        erc721.mint(alice, 1);

        deal(alice, 1 ether);
        deal(bob, 2 ether);
        deal(carol, 2 ether);

        deal(address(linkToken), address(randomGenerator), 20 ether);

        hoax(alice);
        erc721.setApprovalForAll(address(candleAuction), true);

    }

    function testCanRequestRandomness() public {
        uint256 startingRequestId = randomGenerator.latestRequestId();

        hoax(address(candleAuction));
        randomGenerator.requestRandom();
        assertTrue(randomGenerator.latestRequestId() != startingRequestId);
    }

    function testCanGetRandomness() public {

       hoax(address(candleAuction));
       randomGenerator.requestRandom();
       
       uint256 requestId = randomGenerator.latestRequestId();
        
        // When testing locally you MUST call fulfillRandomness youself to get the
        // randomness to the consumer contract, since there isn't a chainlink node on your local network
        vrfCoordinator.fulfillRandomWords(requestId, address(randomGenerator));
        assertTrue(randomGenerator.getRandom() >= 0);

       
    }

    function testCreateAuction() public {
        createAuction(1);
        assertEq( erc721.ownerOf(1), address(candleAuction));
    }

    function testBid() public {
        // Create Auction
        uint256 uid = createAuction(1);
        // Check Bob's previous balance
        uint256 prevBalance = bob.balance;
        // Bob Bids .6 eth at Block 40000
        makeBid(uid, bob, .6 ether, 40000);
        assertEq(bob.balance, prevBalance - .6 ether);      
    }

    function testFailBid() public {
        // Create Auction
        uint256 uid = createAuction(1);
        // Bob Bids .6 eth at Block 40102
        makeBid(uid, bob, .6 ether, 40102);
    }

    function testMultiBid() public {
        // Create Auction
        uint256 uid = createAuction(1);
        // Bob Bids .6 eth at Block 40000
        uint256 prevBobBalance = bob.balance;
        makeBid(uid, bob, .6 ether, 40000);
        assertEq(bob.balance, prevBobBalance - .6 ether); 
        uint256 prevCarolBalance = carol.balance;
        // Carol Bids .65 eth at Block 40101
        makeBid(uid, carol, .65 ether, 40101);
        assertEq(carol.balance, prevCarolBalance - .65 ether);  
    }

    function testMultiBid_SameBlock() public {
        // Create Auction
        uint256 uid = createAuction(1);
        // Bob Bids .6 eth at Block 40100
        uint256 prevBobBalance = bob.balance;
        makeBid(uid, bob, .6 ether, 40100);
        assertEq(bob.balance, prevBobBalance - .6 ether); 
        uint256 prevCarolBalance = carol.balance;
        // Carol Bids .65 eth at Block 40100
        makeBid(uid, carol, .65 ether, 40100);
        assertEq(carol.balance, prevCarolBalance - .65 ether);  
    }

    function testFailMultiBid() public {
        // Create Auction
        uint256 uid = createAuction(1);
        // Bob Bids .6 eth at Block 40100
        uint256 prevBobBalance = bob.balance;
        makeBid(uid, bob, .6 ether, 40100);
        assertEq(bob.balance, prevBobBalance - .6 ether); 
        uint256 prevCarolBalance = carol.balance;
        // Carol Bids .6 eth at Block 40101
        makeBid(uid, carol, .6 ether, 40101);
        assertEq(carol.balance, prevCarolBalance - .6 ether);  
    }

    function testSucessfulAuctionNoPossibleTermination() public {
        // Create Auction
        uint256 uid = createAuction(1);
        makeBid(uid, bob, .6 ether, 15000); 
        // Carol Bids .6 eth at Block 150
        makeBid(uid, carol, .65 ether, 15000); 
       
        endAndSettleAuction(uid, 45000);
        assertEq(erc721.ownerOf(1), carol);
        assertEq(candleAuction.Bids(uid, carol), 0);
        assertEq(candleAuction.Bids(uid, bob), .6 ether);

    }

    function testSucessfulAuctionPossibleTermination() public {
       // Create Auction
        uint256 uid = createAuction(1);
        makeBid(uid, bob, .6 ether, 15000); 

        // Possible Termination Period starts at 20101
        // Carol Bids .65 eth at Block 21000
        makeBid(uid, carol, .65 ether, 21000); 

        // Bob bids an ADDITIONAL .2 ether at Block 22000
        makeBid(uid, bob, .2 ether, 39000);
       
        endAndSettleAuction(uid, 45000);
       
        assertEq(erc721.ownerOf(1), carol);
        assertEq(candleAuction.Bids(uid, carol), 0);
        assertEq(candleAuction.Bids(uid, bob), .8 ether);

    }

    function testFailAuction_InvalidTime() public {
        uint256 uid = createAuction(1);
        makeBid(uid, bob, .6 ether, 15000); 

        // Possible Termination Period starts at 20101
        // Carol Bids .65 eth at Block 21000
        makeBid(uid, carol, .65 ether, 21000); 

        endAndSettleAuction(uid, 30000); 
    }

    function testFailAuction_EndAuctionNotOwner() public {
        uint256 uid = createAuction(1);
        makeBid(uid, bob, .6 ether, 15000); 

        // Possible Termination Period starts at 20101
        // Carol Bids .65 eth at Block 21000
        makeBid(uid, carol, .65 ether, 21000); 

        vm.roll(45000);

        hoax(alice);
        candleAuction.endAuction(uid);
    }

    function testFailAuction_SettleAuctionNotOwner() public {
        uint256 uid = createAuction(1);
        makeBid(uid, bob, .6 ether, 15000); 

        // Possible Termination Period starts at 20101
        // Carol Bids .65 eth at Block 21000
        makeBid(uid, carol, .65 ether, 21000); 

        vm.roll(45000);

        hoax(jim);
        candleAuction.endAuction(uid);

        uint256 requestId = randomGenerator.latestRequestId(); 
        vrfCoordinator.fulfillRandomWords(requestId, address(randomGenerator));
        // Exact time doesn't matter just enough time for fulfillRandomWords to confirm
        skip(72);

        hoax(alice);
        candleAuction.settleAuction(uid);
    }

    function testAuctionWithNoBids() public {

        // Alice creates an auction
        uint256 uid = createAuction(1);
        endAndSettleAuction(uid, 45000); 

        assertEq(erc721.ownerOf(1), alice);
        assertEq(candleAuction.Bids(uid, alice), 0);
    }

    function createAuction(uint32 tokenId) public returns (uint256) {
        hoax(alice);

        uint32[] memory flipsPerPeriod = new uint32[](4);
        flipsPerPeriod[0] = 4;
        flipsPerPeriod[1] = 3;
        flipsPerPeriod[2] = 2;
        flipsPerPeriod[3] = 1;

        return candleAuction.createAuction(address(erc721), tokenId, uint32(block.number + 100), 20000, 20000, .5 ether, 5000, flipsPerPeriod );
        
    }

    function makeBid(uint256 uid, address bidder, uint256 bid, uint32 blockNumber) private {
            vm.roll(blockNumber);
            vm.prank(bidder);
            candleAuction.bid{value: bid}(uid);
    }

    function endAndSettleAuction(uint256 uid, uint32 blockNumber) private {
        vm.roll(blockNumber);

        hoax(jim);
        candleAuction.endAuction(uid);


        uint256 requestId = randomGenerator.latestRequestId(); 
        vrfCoordinator.fulfillRandomWords(requestId, address(randomGenerator));

        skip(72);

        hoax(jim);
        candleAuction.settleAuction(uid);

    }

}
