//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./babyBearToken.sol";
import "./HGCToken.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";



contract randomNumber is RrpRequesterV0, ReentrancyGuard {

    using Counters for Counters.Counter;

    //events for the random number getter:
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
 
    //emit when the user earns a reward
    //reward subs: 0 => tryAgain; 1 => freeSpin; 2 => JackPot; 3 => 1 HGC; 4 => babyBear; 5 => 1 HNY; 6 => 5 HNY
    event RewardReceived(uint256 reward, address _address);

    //emit when the user claims his rewards:
    //reward claimed subs: 0 => freeSpin; 1 => HGC; 2 => babyBear; 3 => HNY
    event RewardClaimed(uint256 reward, address user);

    // These can be set using setRequestParameters())
    address public airnode;
    bytes32 public endpointIdUint256;
    address public sponsorWallet;

    address public owner;

    bool public contractEnabled;

    //tokens addresses
    HGCToken public HGCAddress;
    IERC20 public HNYAddress;
    babyBearToken public babyBearAddress;

    //fee require to spin the wheel
    uint256 public fee = 25 * 10 ** 16;



    //Each user will have its "wallet", so it can be stored the user rewards:
    struct user {
        uint256 freeSpin;
        uint256 HGC;
        uint256 babyBear;
        uint256 HNY;
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

    constructor(address _airnodeRrp, HGCToken _HGCAddress, address _HNYAddress, babyBearToken _babyBearAddress) RrpRequesterV0(_airnodeRrp) {
        owner = msg.sender;
        contractEnabled = true;
        HGCAddress =  _HGCAddress;
        HNYAddress = IERC20(_HNYAddress);
        babyBearAddress = _babyBearAddress;
    }

    function setTokensAddress(HGCToken _HGCAddress, address _HNYAddress, babyBearToken _babyBearAddress) public onlyOwner() {
        HGCAddress =  _HGCAddress;
        HNYAddress = IERC20(_HNYAddress);
        babyBearAddress = _babyBearAddress;
    }

    function setOwner(address _address) public onlyOwner() {
        owner = _address;
    }

    function setFee(uint256 _fee) public onlyOwner() {
        fee = _fee;
    }


    //spin the wheel
    function spinWheel() public  onlyContractEnabled() {
        bool sent = HNYAddress.transferFrom(msg.sender, address(this), fee);
        require(sent, "Failed to spin the wheel");


        makeRequestUint256();


    }

    //free spin
    function freeSpinWheel() internal onlyContractEnabled () {
        makeRequestUint256();
    }

    //claim rewards, you need to specify which reward you want to claim
    // 0 => free spin; 1 => withdraw HGC tokens; 2 => withdraw babyBear tokens; 3 => withdraw HNY tokens.

    function claim(uint256 option) public  onlyContractEnabled() nonReentrant {
        
        if (option == 0) {
            require(addressToUser[msg.sender].freeSpin >= 1, "You dont have 'Free spin' available for claiming");
            addressToUser[msg.sender].freeSpin = addressToUser[msg.sender].freeSpin - 1;
            freeSpinWheel();
            emit RewardClaimed(0, msg.sender);
        }

        if (option == 1) {
            require(addressToUser[msg.sender].HGC >= 1, "You dont have 'HGC' available for claiming");
            uint256 HGCAmount = addressToUser[msg.sender].HGC;
            HGCAddress.publicMint(HGCAmount);

            for (uint256 i = 1; i <= HGCAmount; i++) {
                uint[] memory arrayHGC = HGCAddress.getTokensOwnedByWallet(address(this), 0, 40000);
                uint256 length = arrayHGC.length;
                HGCAddress.safeTransferFrom(address(this), msg.sender, arrayHGC[length - 1]);
                addressToUser[msg.sender].HGC = addressToUser[msg.sender].HGC - 1;
            }
            
            emit RewardClaimed(1, msg.sender);


        }

        if (option == 2) {
            require(addressToUser[msg.sender].babyBear >= 1, "You dont have 'BabyBear' available for claiming");
            uint256 babyBearAmount = addressToUser[msg.sender].babyBear;
            babyBearAddress.publicMint(babyBearAmount);

            for (uint256 i = 1; i <= babyBearAmount; i++) {
                uint[] memory arrayBabyBears = babyBearAddress.getTokensOwnedByWallet(address(this), 0, 40000);
                uint256 length = arrayBabyBears.length;
                babyBearAddress.safeTransferFrom(address(this), msg.sender, arrayBabyBears[length - 1]);
                addressToUser[msg.sender].babyBear = addressToUser[msg.sender].babyBear - 1;
            }
            
            emit RewardClaimed(2, msg.sender);

        }

        if (option == 3) {
            require(addressToUser[msg.sender].HNY >= 1, "You dont have HNY' available for claiming");
            bool sent = HNYAddress.transfer(msg.sender, addressToUser[msg.sender].HNY * 10 ** 18);
            require(sent, "Failed to withdraw the tokens");
            addressToUser[msg.sender].HNY = 0;

            emit RewardClaimed(3, msg.sender);
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
        
        uint256 randomic = ((qrngUint256) % 999);

        if (randomic >= 0 && randomic <= 449){
            emit RewardReceived(0, requestIdToAddress[requestId]);
        }

        if (randomic >= 450 && randomic <= 649){
            addressToUser[requestIdToAddress[requestId]].freeSpin = addressToUser[requestIdToAddress[requestId]].freeSpin + 1;
            emit RewardReceived(1, requestIdToAddress[requestId]);
        }

        if (randomic >= 650 && randomic <= 654){
            addressToUser[requestIdToAddress[requestId]].HGC = addressToUser[requestIdToAddress[requestId]].HGC + 3;
            emit RewardReceived(2, requestIdToAddress[requestId]);
        }

        if (randomic >= 655 && randomic <= 669){
            addressToUser[requestIdToAddress[requestId]].HGC = addressToUser[requestIdToAddress[requestId]].HGC + 1;
            emit RewardReceived(3, requestIdToAddress[requestId]);
        }

        if (randomic >= 670 && randomic <= 769){
            addressToUser[requestIdToAddress[requestId]].babyBear = addressToUser[requestIdToAddress[requestId]].babyBear + 1;
            emit RewardReceived(4, requestIdToAddress[requestId]);
        }

        if (randomic >= 770 && randomic <= 969){
            addressToUser[requestIdToAddress[requestId]].HNY = addressToUser[requestIdToAddress[requestId]].HNY + 1;
            emit RewardReceived(5, requestIdToAddress[requestId]);
        }

        if (randomic >= 970 && randomic <= 999){
            addressToUser[requestIdToAddress[requestId]].HNY = addressToUser[requestIdToAddress[requestId]].HNY + 5;
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

    function witdrawETH(uint256 _weiAmount) public onlyOwner() {
        payable(msg.sender).transfer(_weiAmount);
    }

    function withdrawTokens() public onlyOwner() {
        uint256 HNYtotalAmount = HNYAddress.balanceOf(address(this));
        HNYAddress.transfer(msg.sender, HNYtotalAmount);

        //withdraw babyBearTokens:
        uint256 babyBearAmount = babyBearAddress.balanceOf(address(this));
        for (uint256 i = 1; i <= 3; i++){
            uint256[] memory arrayBabyBear = babyBearAddress.getTokensOwnedByWallet(address(this), 0, 40000);
            uint256 length = arrayBabyBear.length;
            babyBearAddress.transferFrom(address(this), msg.sender, i);
        } 
        
        
        //withdraw HGCTokens:
        uint256 HGCAmount = HGCAddress.balanceOf(address(this));
        for (uint256 i = 0; i <= HGCAmount; i++){
                uint[] memory arrayHGC = HGCAddress.getTokensOwnedByWallet(address(this), 0, 40000);
                uint256 length = arrayHGC.length;
                HGCAddress.safeTransferFrom(address(this), msg.sender, arrayHGC[length - 1]);
        } 
    }

}
