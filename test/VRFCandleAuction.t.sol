// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//import "forge-std/Test.sol";
import "../src/VRFCandleAuction.sol";
import "../src/IVRFCandleAuctionErrors.sol";
import "./utils/TestActors.sol";
import "./utils/TestERC721.sol";
import "./utils/TestERC20.sol";

contract VRFCandleAuctionTest is IVRFCandleAuctionErrors, TestActors {
    
    VRFCandleAuction candleAuction;
    TestERC721 erc721;
    TestERC20 erc20;

    function setUp() public override {
        candleAuction = new VRFCandleAuction(address(erc20));
        erc721 = new TestERC721();
        erc20 = new TestERC20();
        erc721.mint(alice, 1);

        erc20.mint(alice, 5 ether);
        deal(alice, 1 ether);
        deal(bob, 2 ether);
        deal(carol, 2 ether);

        deal(address(erc20), address(candleAuction), 20 ether);

        hoax(alice);
        erc721.setApprovalForAll(address(candleAuction), true);
    }

    function testCreateAuction() public {
        createAuction(1);
        assertEq( erc721.ownerOf(1), address(candleAuction));
    }

    function testBid() public {
        // Create Auction
        createAuction(1);
        // Check Bob's previous balance
        uint256 prevBalance = bob.balance;
        // Bob Bids .6 eth at Block 200
        makeBid(1, 1, bob, .6 ether, 200);
        assertEq(bob.balance, prevBalance - .6 ether);      
    }

    function testFailBid() public {
        // Create Auction
        createAuction(1);
        // Bob Bids .6 eth at Block 204
        makeBid(1, 1, bob, .6 ether, 204);
    }

    function testMultiBid() public {
        // Create Auction
        createAuction(1);
        // Bob Bids .6 eth at Block 200
        uint256 prevBobBalance = bob.balance;
        makeBid(1, 1, bob, .6 ether, 200);
        assertEq(bob.balance, prevBobBalance - .6 ether); 
        uint256 prevCarolBalance = carol.balance;
        // Carol Bids .65 eth at Block 201
        makeBid(1, 2, carol, .65 ether, 201);
        assertEq(carol.balance, prevCarolBalance - .65 ether);  
    }

    function testMultiBid_SameBlock() public {
        // Create Auction
        createAuction(1);
        // Bob Bids .6 eth at Block 200
        uint256 prevBobBalance = bob.balance;
        makeBid(1, 1, bob, .6 ether, 200);
        assertEq(bob.balance, prevBobBalance - .6 ether); 
        uint256 prevCarolBalance = carol.balance;
        // Carol Bids .65 eth at Block 200
        makeBid(1, 2, carol, .65 ether, 200);
        assertEq(carol.balance, prevCarolBalance - .65 ether);  
    }

    function testFailMultiBid() public {
        // Create Auction
        createAuction(1);
        // Bob Bids .6 eth at Block 200
        uint256 prevBobBalance = bob.balance;
        makeBid(1, 1, bob, .6 ether, 200);
        assertEq(bob.balance, prevBobBalance - .6 ether); 
        uint256 prevCarolBalance = carol.balance;
        // Carol Bids .6 eth at Block 201
        makeBid(1, 2, carol, .6 ether, 201);
        assertEq(carol.balance, prevCarolBalance - .6 ether);  
    }

    function testSucessfulAuction() public {
        // Create Auction
        createAuction(1);
        makeBid(1, 1, bob, .6 ether, 115); 
        // Carol Bids .6 eth at Block 150
        makeBid(1, 1, carol, .65 ether, 115); 
       
        endAuction(1, 1, 250);
        assertEq(erc721.ownerOf(1), carol);
        assertEq(candleAuction.Bids(address(erc721), 1, 1, carol), 0);
    }

    

    function createAuction(uint32 id) private {
        hoax(alice);
        candleAuction.createAuction(address(erc721), id, uint32(block.number + 100), 26, 76, .5 ether);
    }

    function makeBid(uint32 id, uint32 auctionIndex, address bidder, uint256 bid, uint32 blockNumber) private {
            vm.roll(blockNumber);
            vm.prank(bidder);
            candleAuction.bid{value: bid}(address(erc721), id, auctionIndex);
    }

    function endAuction(uint32 id, uint32 auctionIndex, uint32 blockNumber) private {
        vm.roll(blockNumber);
        hoax(alice);
        candleAuction.endAuction(address(erc721), id, auctionIndex);
    }

}
