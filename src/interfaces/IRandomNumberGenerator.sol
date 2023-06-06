// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IRandomNumberGenerator {
    /**
     * Requests randomness from a user-provided seed
     */
    function requestRandom() external;

    /**
     * Views random result
     */
    function getRandom() external view returns (uint256);
}