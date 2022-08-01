//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ArcadeWheel is RrpRequesterV0, ReentrancyGuard {

    using Counters for Counters.Counter;

    //events for the random number getter:
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
 
    //emit when the user earns a reward
    //reward subs: 0 => tryAgain; 1 => freeSpin; 2 => JackPot; 3 => 150 USDC; 4 => 50 USDC; 5 => 10 USDC; 6 => 5 USDC
    event RewardReceived(uint256 reward, address _address);

    //emit when the user claims his rewards:
    //reward claimed subs: 0 => freeSpin; 2 => HNY; 3 => USDC; 4 => all
    event RewardClaimed(uint256 reward, address user);

    // These can be set using setRequestParameters())
    address public airnode;
    bytes32 public endpointIdUint256;
    address public sponsorWallet;

    address public owner;

    bool public contractEnabled;

    //tokens addresses
    IERC20 public USDCAddress;

    //fee require to spin the wheel
    uint256 public fee = 5 * 10 ** 6;

    //Each user will have its "wallet", so it can be stored the user rewards:
    struct user {
        uint256 freeSpin;
        uint256 USDC;
    }

    //mappings:
    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;
    mapping(address => user) public addressToUser;
    mapping(bytes32 => address) public requestIdToAddress;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // function to enable/disable contract, in case of error or exploit:
    modifier onlyContractEnabled() {
        require(contractEnabled == true);
        _;
    }

    constructor(address _airnodeRrp, address _USDCAddress) RrpRequesterV0(_airnodeRrp) {
        owner = msg.sender;
        contractEnabled = true;
        USDCAddress = IERC20(_USDCAddress);
    }

    function setTokensAddress(address _USDCAddress) public onlyOwner() {
        USDCAddress = IERC20(_USDCAddress);
    }

    function setOwner(address _address) public onlyOwner() {
        owner = _address;
    }

    function setFee(uint256 _fee) public onlyOwner() {
        fee = _fee;
    }


    //spin the wheel
    function spinWheel() public  onlyContractEnabled() {
        bool sent = USDCAddress.transferFrom(msg.sender, address(this), fee);
        require(sent, "Failed to spin the wheel");

        makeRequestUint256();

    }

    //free spin
    function freeSpinWheel() private onlyContractEnabled() {
        makeRequestUint256();
    }

    //claiming FreeSpin tokens:
    function claimFreeSpin() public onlyContractEnabled() nonReentrant {
            require(addressToUser[msg.sender].freeSpin >= 1, "You dont have 'Free spin' available for claiming");
            addressToUser[msg.sender].freeSpin = addressToUser[msg.sender].freeSpin - 1;
            freeSpinWheel();
            emit RewardClaimed(0, msg.sender);
    }


    //claiming USDC tokens:
    function claimUSDC() public onlyContractEnabled() nonReentrant {
            require(addressToUser[msg.sender].USDC >= 1, "You dont have USDC available for claiming");
            uint256 USDCAmount = addressToUser[msg.sender].USDC;
            addressToUser[msg.sender].USDC = 0;
            bool sent = USDCAddress.transfer(msg.sender, USDCAmount * 10 ** 18);
            require(sent, "Failed to withdraw the tokens");
            emit RewardClaimed(3, msg.sender);
    }


    // Set parameters used by airnodeRrp.makeFullRequest(...)
    // See makeRequestUint256()
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        address _sponsorWallet
    ) external {
        // Normally, this function should be protected, as in:
        // require(msg.sender == owner, "Sender not owner");
        require(msg.sender == owner);
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        sponsorWallet = _sponsorWallet;
    }

    // Calls the AirnodeRrp contract with a request
    // airnodeRrp.makeFullRequest() returns a requestId to hold onto.
    function makeRequestUint256() private {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );
        // Store the requestId
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        requestIdToAddress[requestId] = msg.sender;
        emit RequestedUint256(requestId);
    }



    // AirnodeRrp will call back with a response
    function fulfillUint256(bytes32 requestId, bytes calldata data)
        external
        onlyAirnodeRrp
    {
        // Verify the requestId exists
        require(
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request ID not known"
        );

        
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 qrngUint256 = abi.decode(data, (uint256));
        
        uint256 randomic = ((qrngUint256) % 99999);

        if (randomic >= 0 && randomic <= 58349){
            emit RewardReceived(0, requestIdToAddress[requestId]);
        }

        if (randomic >= 58350 && randomic <= 78349){
            addressToUser[requestIdToAddress[requestId]].freeSpin = addressToUser[requestIdToAddress[requestId]].freeSpin + 1;
            emit RewardReceived(1, requestIdToAddress[requestId]);
        }

        if (randomic >= 78350 && randomic <= 78449){
            addressToUser[requestIdToAddress[requestId]].USDC = addressToUser[requestIdToAddress[requestId]].USDC + 500;
            emit RewardReceived(2, requestIdToAddress[requestId]);
        }

        if (randomic >= 78450 && randomic <= 78699){
            addressToUser[requestIdToAddress[requestId]].USDC = addressToUser[requestIdToAddress[requestId]].USDC + 150;
            emit RewardReceived(3, requestIdToAddress[requestId]);
        }

        if (randomic >= 78700 && randomic <= 79199){
            addressToUser[requestIdToAddress[requestId]].USDC = addressToUser[requestIdToAddress[requestId]].USDC + 50;
            emit RewardReceived(4, requestIdToAddress[requestId]);
        }

        if (randomic >= 79200 && randomic <= 84199){
            addressToUser[requestIdToAddress[requestId]].USDC = addressToUser[requestIdToAddress[requestId]].USDC + 10;
            emit RewardReceived(5, requestIdToAddress[requestId]);
        }

        if (randomic >= 84200 && randomic <= 99999){
            addressToUser[requestIdToAddress[requestId]].USDC = addressToUser[requestIdToAddress[requestId]].USDC + 5;
            emit RewardReceived(6, requestIdToAddress[requestId]);
        }
        emit ReceivedUint256(requestId, qrngUint256);
    }

    function fundMe() public payable{
    }


    function returnUserWallet(address _address) public view returns(user memory){
        return addressToUser[_address];
    }


    function enableContract(bool _bool) public onlyOwner() {
        contractEnabled = _bool;
    }

    function withdraw(uint256 _weiAmount) public onlyOwner() {
        payable(msg.sender).transfer(_weiAmount);
    }

    function withdrawTokens() public onlyOwner() {
        uint256 USDCTotalAmount = USDCAddress.balanceOf(address(this));
        if (USDCTotalAmount > 0){
            USDCAddress.transfer(msg.sender, USDCTotalAmount);
        }
    }

}