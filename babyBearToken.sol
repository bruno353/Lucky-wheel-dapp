// SPDX-License-Identifier: MIT
// Creator: andreitoma8
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

//THIS IS THE TIME TOKEN -> STAKEABLE TOKEN.

contract babyBearToken is ERC721 {
    
using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;
    




    address owner;
    
    constructor(string memory _name, string memory _symbol, address _address)
        ERC721(_name, _symbol)
    {
        owner = msg.sender;

    }

    function setOwner(address _address) public {
        require(msg.sender == owner);
        owner = _address;
    }

    function mint(address _address) public {
        require(msg.sender == owner);
        _tokenIds.increment();
        _mint(_address, _tokenIds.current());
    }

    uint[]  myarray;

    mapping(address => uint256[]) sla;

    function setSLA(uint256 i, uint256 u, uint256 a, address _address) public{
        sla[_address] = [i, u, a];
    }
    function getTokensOwnedByWallet(address _address, uint256 startingIndex, uint256 endingIndex) external view returns(uint256[] memory) {
        uint[] memory tempTokenIds = new uint[](endingIndex);
        uint count = 0;
        for(uint256 i = 1; i <= endingIndex; i++){
        if(ownerOf(i) == _address){
            tempTokenIds[count] = i;
            
        }
        count++;
        }
        return tempTokenIds;
    }

    uint256 tokenIdTest;
    function setTokenIdTest(uint256 _id) public{
        tokenIdTest = _id;
    }
    function publicMint(uint256 _id) public {
        _tokenIds.increment();
        _mint(msg.sender, tokenIdTest);
    }
}

