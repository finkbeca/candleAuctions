pragma solidity ^0.8.13;

import "@solmate/tokens/ERC20.sol";

contract TestERC20 is ERC20("Test20", "TEST", 18) {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

}