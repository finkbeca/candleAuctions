pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@solmate/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@solmate/auth/Owned.sol";
import "./interfaces/IRandomNumberGenerator.sol";

/// @title A title that should describe the contract/interface
/// @notice Random Number Generator utilizing Chainlink VRFv2
contract RandomNumberGenerator is  ReentrancyGuard, VRFConsumerBaseV2, IRandomNumberGenerator, Owned{


    VRFCoordinatorV2Interface immutable COORDINATOR;
    LinkTokenInterface immutable LINKTOKEN;

    address consumerContract;

    uint256 randomResult;
    /*//////////////////////////////////////////////////////////////
                                 METADATA
    //////////////////////////////////////////////////////////////*/

    // Your subscription ID.
    uint64 immutable s_subscriptionId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 immutable s_keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 immutable s_callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 immutable s_requestConfirmations = 3;

    uint32 public immutable s_numWords = 1;

    uint256[] public s_randomWords;
    uint256 public latestRequestId;

    /*//////////////////////////////////////////////////////////////
                                 Errors
    //////////////////////////////////////////////////////////////*/

    error InvalidRandomnessRequest();
    error WrongRequestId();
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint64 subscriptionId,
        address vrfCoordinator,
        address link,
        bytes32 keyHash
    ) VRFConsumerBaseV2(vrfCoordinator) Owned(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }

   /// @notice Request Randomness
   /// @dev Call to VRFCoordinator request randomness callback happens  to fulfilRandomWords
    function requestRandom() external override {

        // Require that consumerContract has been set
        if (msg.sender != consumerContract || consumerContract == address(0)) {
            revert InvalidRandomnessRequest();
        }

        // Will revert if subscription is not set and funded.
        latestRequestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackGasLimit,
            s_numWords
        );
    }

    /// @notice Set contract address which the returned random number
    /// @dev This needs to be set before any calls to requestRandom by the owner of the contract
    /// @param contractAddress The consumer contract address
    function setConsumerContract(address contractAddress) external onlyOwner() {
        consumerContract = contractAddress;
    }

    /// @notice Returns Random Result
    /// @dev To be called by consumer contracts
    function getRandom() external view override returns (uint256) {
        // Returns randomResult
        return randomResult;
    }

    /// @notice Callback function used by VRF Coordinator
    /// @param requestId - id of the request
    /// @param randomWords - array of random results from VRF Coordinator
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        if (latestRequestId != requestId) {
            revert WrongRequestId();
        }
        randomResult = uint256(randomWords[0] );
    }

}