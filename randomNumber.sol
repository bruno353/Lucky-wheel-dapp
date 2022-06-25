//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./babyBearToken.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";





contract randomNumber is RrpRequesterV0, ReentrancyGuard {

    using Counters for Counters.Counter;
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
 
    Counters.Counter public _addressCounter;


    //emit when the user earns a reward
    //reward subs: 0 => tryAgain; 1 => freeSpin; 2 => JackPot; 3 => 1 HGC; 4 => babyBear; 5 => 1 HNY; 6 => 5 HNY;
    event RewardReceived(uint256 reward, address _address);

    // These can be set using setRequestParameters())
    address public airnode;
    bytes32 public endpointIdUint256;
    address public sponsorWallet;

    address public owner;

    //tokens addresses
    IERC20 public HGCtokenAddress;
    IERC20 public HNYtokenAddress;
    babyBearToken public babyBearAddress;

    //fee require to spin the wheel
    uint256 public rate = 2 * 10 ** 17;



    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;

    //Each user will have its "wallet"
    struct user {
        uint256 freeSpin;
        uint256 HGC;
        uint256 babyBear;
        uint256 HNY;
    }

    mapping(address => user) public addressToUser;
    mapping(uint256 => address) public counterToAddress;


    mapping(bytes32 => address) public requestIdToAddress;

    constructor(address _airnodeRrp, address _HGCtokenAddress, address _HNYtokenAddress, babyBearToken _babyBearAddress) RrpRequesterV0(_airnodeRrp) {
        owner = msg.sender;
        HGCtokenAddress =  IERC20(_HGCtokenAddress);
        HNYtokenAddress = IERC20(_HNYtokenAddress);
        babyBearAddress = _babyBearAddress;
    }

    function setTokensAddress(address _HGCtokenAddress, address _HNYtokenAddress, babyBearToken _babyBearAddress) public {
        require(msg.sender == owner);
        HGCtokenAddress =  IERC20(_HGCtokenAddress);
        HNYtokenAddress = IERC20(_HNYtokenAddress);
        babyBearAddress = _babyBearAddress;
    }


    //spin the wheel
    function spinWheel() public  {
        bool sent = HNYtokenAddress.transferFrom(msg.sender, address(this), rate);
        require(sent, "Failed to spin the wheel");

        _addressCounter.increment();
        counterToAddress[_addressCounter.current()] = msg.sender;

        makeRequestUint256();


    }

    //claim rewards, you need to specify which reward you want to claim
    // 0 => free spin; 1 => withdraw HGC tokens; 2 => withdraw babyBear tokens; 3 => withdraw HNY tokens.


    //bug: nonreentrancy bug -> quando faz o claim do freeSpin.
    function claim(uint256 option) public  {
        
        if (option == 0) {
            require(addressToUser[msg.sender].freeSpin >= 1, "You dont have 'Free spin' available for claiming");
            addressToUser[msg.sender].freeSpin = addressToUser[msg.sender].freeSpin - 1;
            spinWheel();
        }

        if (option == 1) {
            require(addressToUser[msg.sender].HGC >= 1, "You dont have 'HGC' available for claiming");
            bool sent = HGCtokenAddress.transfer(msg.sender, addressToUser[msg.sender].HGC * 10 ** 18);
            require(sent, "Failed to withdraw the tokens");
            addressToUser[msg.sender].HGC = 0;
        }

        if (option == 2) {
            require(addressToUser[msg.sender].babyBear >= 1, "You dont have 'BabyBear' available for claiming");
            babyBearAddress.mint(msg.sender);
            addressToUser[msg.sender].babyBear = addressToUser[msg.sender].babyBear - 1;
        }

        if (option == 3) {
            require(addressToUser[msg.sender].HNY >= 1, "You dont have 'HYN' available for claiming");
            bool sent = HNYtokenAddress.transfer(msg.sender, addressToUser[msg.sender].HNY * 10 ** 18);
            require(sent, "Failed to withdraw the tokens");
            addressToUser[msg.sender].HNY = 0;
        }
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
    function makeRequestUint256() internal {
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

    mapping(uint256 => address) public deus;

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
        // Do what you want with `qrngUint256` here...

        uint256 randomic = ((qrngUint256) % 999);

        deus[1] = counterToAddress[_addressCounter.current()];

        if (randomic >= 0 && randomic <= 449){
            emit RewardReceived(0, counterToAddress[_addressCounter.current()]);
        }

        if (randomic >= 450 && randomic <= 649){
            addressToUser[counterToAddress[_addressCounter.current()]].freeSpin = addressToUser[counterToAddress[_addressCounter.current()]].freeSpin + 1;
            emit RewardReceived(1, counterToAddress[_addressCounter.current()]);
        }

        if (randomic >= 650 && randomic <= 654){
            addressToUser[counterToAddress[_addressCounter.current()]].HGC = addressToUser[counterToAddress[_addressCounter.current()]].HGC + 1;
            emit RewardReceived(2, counterToAddress[_addressCounter.current()]);
        }

        if (randomic >= 655 && randomic <= 669){
            addressToUser[counterToAddress[_addressCounter.current()]].HGC = addressToUser[counterToAddress[_addressCounter.current()]].HGC + 1;
            emit RewardReceived(3, counterToAddress[_addressCounter.current()]);
        }

        if (randomic >= 670 && randomic <= 769){
            addressToUser[counterToAddress[_addressCounter.current()]].babyBear = addressToUser[counterToAddress[_addressCounter.current()]].babyBear + 1;
            emit RewardReceived(4, counterToAddress[_addressCounter.current()]);
        }

        if (randomic >= 770 && randomic <= 969){
            addressToUser[counterToAddress[_addressCounter.current()]].HNY = addressToUser[counterToAddress[_addressCounter.current()]].HNY + 1;
            emit RewardReceived(5, counterToAddress[_addressCounter.current()]);
        }

        if (randomic >= 970 && randomic <= 999){
            addressToUser[counterToAddress[_addressCounter.current()]].HNY = addressToUser[counterToAddress[_addressCounter.current()]].HNY + 5;
            emit RewardReceived(6, counterToAddress[_addressCounter.current()]);
        }
        addressToUser[counterToAddress[_addressCounter.current()]].babyBear = addressToUser[counterToAddress[_addressCounter.current()]].babyBear + 1;
        emit ReceivedUint256(requestId, qrngUint256);
    }

    function fundMe() public payable{
    }

    function returnUserWallet(address _address) public view returns(user memory){
        return addressToUser[_address];
    }
}
