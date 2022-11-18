//SPDX-License-Identifier: MIT

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ChainlinkClient.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ConfirmedOwner.sol";
import "https://github.com/BenRiekes/Smart-Contracts/blob/main/AuraStorage.sol";
 

pragma solidity ^0.8.12;

contract AuraNode is AuraStorage, ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    //Events: ===========================================================================================

    event NodeTrigger (
        bytes32 indexed JobID,
        string PoapID,
        address Collector,
        string URL,
        uint256 TimeOfTrigger
    );

    event NodeFullfill (
        bytes32 indexed PoapID,
        string PoapName,
        address Collector,
        bool CollectorMintStatus,
        uint256 TimeOfFullfill
    ); 

    //Chainlink Vars: 
    uint256 private fee; 
    bytes32 private jobId; 

    //Chainlink Constructor:
    constructor() ConfirmedOwner (msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xD5932a0D16bB40De97894E60e1159DA4FbcaC9a6); 

        jobId = 'b5d24c4713824eb180416bc795758d72'; 
        fee = (1 * LINK_DIVISIBILITY) / 10 ** 18; 
    }

    //Helper Functions:  ===========================================================================================

    //Addr => String 
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);            
        }
        return string(s);
    }

    //Char: 
    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    //String => Address:
    function toAddress (string calldata str) internal pure returns (address addr) {

        bytes memory bytesStr = abi.encodePacked(str); 

        assembly {
            addr:= mload(add(bytesStr, 20))
        }
    }

    //Chainlink Functions:  ===========================================================================================

    //Chainlink Request Mint Status:
    function requestMintStatus(string calldata eventId) public {



        Chainlink.Request memory req = buildChainlinkRequest (

            jobId,
            address(this),
            this.fulfillMintStatus.selector
        );
        
        string memory url = string.concat(

            "https://us-central1-aura-3b019.cloudfunctions.net/testNode","?uid=",
            toAsciiString(msg.sender),
            "&eventId=",
            eventId
        );

        req.add('fetchURL', url);
        sendChainlinkRequest(req, fee);

        emit NodeTrigger (jobId, eventId, msg.sender, url, block.timestamp);  
    }

    //Chainlink Fullfill Mint Status: 
    function fulfillMintStatus (bytes32 requestId, bool _canMint, string calldata _requester, string calldata _eventId) public recordChainlinkFulfillment (requestId) {
        
        bytes32 _poapID = bytes32(bytes(_eventId));
        address _user = toAddress(_requester); 

        IDToPoap[_poapID].canMint[_user] = _canMint;

        emit NodeFullfill (_poapID, IDToPoap[_poapID].poapName, _user, _canMint, block.timestamp);  
    }


    //Chainlink Withdrawl 
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }

    //Reset JobID
    function setJobId(bytes32 _jobId) public onlyOwner {
        jobId = _jobId;
    }

}
