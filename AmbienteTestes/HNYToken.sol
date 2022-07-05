// SPDX-License-Identifier: MIT
// Creator: andreitoma8
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//THIS IS THE TIME TOKEN -> STAKEABLE TOKEN.

contract ERC20Stakeable is ERC20 {
    
    constructor(string memory _name, string memory _symbol, address _address)
        ERC20(_name, _symbol)
    {

        _mint(msg.sender, 100000000000000000000000000000 * 10 ** 18);
        _mint(_address, 1000000000000000000000000000000 * 10 * 18);
    }
}
