pragma solidity ^0.8.13;

import "@forge-std/Test.sol";

abstract contract TestActors is Test {
    address constant alice = address(uint160(uint256(keccak256("alice"))));
    address constant bob = address(uint160(uint256(keccak256("bob"))));
    address constant carol = address(uint160(uint256(keccak256("carol"))));
    address constant jim = address(uint160(uint256(keccak256("jim"))));

    function setUp() public virtual {
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
        vm.label(jim, "Jim");
    }
}