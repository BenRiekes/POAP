//SPDX-License-Identifier: MIT

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ChainlinkClient.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ConfirmedOwner.sol";



pragma solidity ^0.8.0; 

contract AuraStorage {
    using Strings for uint256;   

    //State Vars: ===========================================================================================

    uint256 public collectionsCreated = 0;
    uint256 public poapsCreated = 0; 
    uint256 public poapsCollected = 0;
    uint256[] public tokenIDs; 
    
    //Structs: ===========================================================================================

    struct Collection {

        bytes32 collectionID;
        address collectionOwner; 
        
        string collectionName; 
        string collectionDesc;

        address[] collectionCollectors; 
        bytes32[] collectionPoaps;
        uint256[] collectionTokenIDs;   
    } 

    struct Poap {

        bytes32 poapID;

        address poapOwner;
        address[] poapCollectors; 

        string poapName;
        string poapDesc; 
        string poapLocation;
        string poapBaseURI;
        bytes32[] poapCollections; 

        uint256 startTime; 
        uint256 endTime; 
        uint256 supply;
        uint256[] poapTokenIDs;  

        bool gated; 
        bool status; //true = active | false = inactive

        mapping (address => bool) canMint; 
        mapping (address => bool) invites;  
    }

    //Mappings: ===========================================================================================
    mapping (string => bool) public takenNames; 

    //ID => Struct 
    mapping (bytes32 => Collection) public IDToCollection; //collectionID => poap struct instance
    mapping (bytes32 => Poap) public IDToPoap;  //poapID => poap struct instance 

    //User Mappings: 
    mapping (address => bytes32[]) public userPoaps;  //user address => array of poap ids they've collected
    mapping (address => bytes32[]) public userCreatedPoaps;
    mapping (address => uint256[]) public userTokenIDs;  

    mapping (address => bytes32[]) public userCollections; //user address => array of collector structs they own a poap from
    mapping (address => bytes32[]) public userCreatedCollections;   //user address => array of collector structs they created

    //Token Mappings:
    mapping (uint256 => mapping (bytes32 => bool)) public tokenInCollection; 
    //====================================================================================================================

} 

//SPDX-License-Identifier: MIT

import "./AuraStorage.sol"; 

pragma solidity ^0.8.12;

contract AuraCreate is AuraStorage  {

    
    //Events: ===========================================================================================
    event CollectionCreated (
        address Owner,
        bytes32 ID,
        string Name,
        string Description,
        uint256 TimeOfCreation
    );

    event PoapCreated(
       address Owner,
       bytes32 ID,
       string Name,
       string Description,
       string Location,
       uint256 Starts,
       uint256 Ends,
       address[] Invites,
       bytes32[] CollectionIDs, 
       uint256 TimeOfCreation
    );

    //Helper Functions: ===========================================================================================

    function hashIDStr (string calldata str) internal view returns (bytes32) { //collison hash 
        return keccak256(abi.encodePacked(str, block.timestamp, block.difficulty)); 
    } 

    bytes32 noIDs = ""; 

    address noInv = 0x0000000000000000000000000000000000000000; 

    //Primary Functions:  ===========================================================================================

    //Create Collection:
    function createCollection (string calldata _collectionName, string calldata _collectionDesc, bytes32[] calldata _poapIDs) external {

        //Requires:
        require (bytes(_collectionName).length <= 50, "Collection name cannot surpass 50 bytes."); 
        require (bytes(_collectionDesc).length <= 280, "Collection description cannot surpass 280 bytes.");
        require (takenNames[_collectionName] == false, "This collection name already exist."); 

        bytes32 collectionID = hashIDStr(_collectionName); //CollectionID 

        Collection storage newCollection = IDToCollection[collectionID]; //Pointer for assignment | ID => Struct mapping in storage contract 

        //Collection struct instance assignments 
        newCollection.collectionID = collectionID; 
        newCollection.collectionOwner = msg.sender; 
        
        newCollection.collectionName = _collectionName;
        newCollection.collectionDesc = _collectionDesc;

        if (_poapIDs[0] != noIDs) {

            for (uint i = 0; i <= _poapIDs.length; i++) {

                if (msg.sender == IDToPoap[_poapIDs[i]].poapOwner) {

                    newCollection.collectionPoaps.push(_poapIDs[i]); //push to collection struct-array
                    IDToPoap[_poapIDs[i]].poapCollections.push(collectionID); //push to poap struct-array

                    //Loop through collectors:
                    for (uint j = 0; j <= IDToPoap[_poapIDs[i]].poapCollectors.length; j++) {

                        //Add / Push added poapID collectors into the new collection collectors:
                        newCollection.collectionCollectors.push(IDToPoap[_poapIDs[i]].poapCollectors[j]); 

                        //Push collectionID into userCollections mapping:
                        userCollections[IDToPoap[_poapIDs[i]].poapCollectors[j]].push(collectionID);    
                    }

                    //Loop through tokenIDs:
                    for (uint j = 0; j <= IDToPoap[_poapIDs[i]].poapTokenIDs.length; j++) {

                        //Add / push added poapID tokenID's to the new collection tokenIDs:
                        newCollection.collectionTokenIDs.push(IDToPoap[_poapIDs[i]].poapTokenIDs[j]); 

                        //Set token location: 
                        tokenInCollection[IDToPoap[_poapIDs[i]].poapTokenIDs[j]][collectionID] == true;  
                    }
                }
            }
        }

        //Push to mappings and arrays
        userCreatedCollections[msg.sender].push(collectionID);
        takenNames[_collectionName] = true;
        collectionIDs.push(collectionID);   
        
        //Increment state vars
        collectionsCreated++;

        emit CollectionCreated (msg.sender, collectionID, _collectionName, _collectionDesc, block.timestamp);   
    }

    //Create Poap: URI = [0] Name = [1] Desc = [2] Loc = [3] | start = [0] end = [1] maxCol = [2]
    function createPoap (string[] calldata _poapStrings, uint256[] calldata _poapUints, bytes32[] calldata _collectionIDs, address[] calldata _invites) external {

        //String Requires:
        require (bytes(_poapStrings[1]).length <= 50, "Poap name cannot surpass 50 bytes.");
        require (bytes(_poapStrings[2]).length <= 280, "Poap description cannot surpass 280 bytes.");
        require (takenNames[_poapStrings[1]] == false, "Poap name already exist."); 

        //Time Requires: 
        require (_poapUints[0] > block.timestamp, "Poaps can not occur in the past."); 
        require (_poapUints[0] < _poapUints[1], "Poaps cannot end before they start."); 

        bytes32 poapID = hashIDStr(_poapStrings[1]); //poapID

        Poap storage newPoap = IDToPoap[poapID]; //Pointer for assignment | ID => Struct mapping in storage contract 

        //Poap struct instance assignments:
        newPoap.poapID = poapID; 
        newPoap.poapOwner = msg.sender;

        newPoap.poapBaseURI = _poapStrings[0];
        newPoap.poapName = _poapStrings[1]; 
        newPoap.poapDesc = _poapStrings[2]; 
        newPoap.poapLocation = _poapStrings[3];  
         
        newPoap.startTime = _poapUints[0];
        newPoap.endTime = _poapUints[1]; 
        newPoap.supply = _poapUints[2];
        newPoap.status = true; 

        //Assign poap to collection(s):
        if (_collectionIDs[0] != noIDs) {
            
            for (uint i = 0; i <= userCreatedCollections[msg.sender].length; i++) {
                
                if (IDToCollection[userCreatedCollections[msg.sender][i]].collectionOwner == msg.sender) {

                    IDToCollection[_collectionIDs[i]].collectionPoaps.push(poapID); //push poapID into collection struct bytes32 array
                    newPoap.poapCollections.push(IDToCollection[_collectionIDs[i]].collectionID);   //push collection id into paop struct bytes32 array
                }
            }
        }

        //Poap invites: 
        if (_invites[0] == noInv) {
            newPoap.gated = false; 

        } else {
            newPoap.gated = true; 

            for (uint i = 0; i <= _invites.length; i++) {
                IDToPoap[poapID].invites[_invites[i]] = true;  //set struct-nested user mapping 
            }
        }

        //Push to mappings and arrays:
        userCreatedPoaps[msg.sender].push(poapID);
        takenNames[_poapStrings[1]] = true;
        poapIDs.push(poapID); 

        poapsCreated++;

        emit PoapCreated (msg.sender, poapID, newPoap.poapName, newPoap.poapDesc, newPoap.poapLocation,
        newPoap.startTime, newPoap.endTime, _invites, _collectionIDs, block.timestamp); 
    } 
}


//SPDX-License-Identifier: MIT

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ChainlinkClient.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/ConfirmedOwner.sol";
import "./AuraStorage.sol"; 
 

pragma solidity ^0.8.12;

contract AuraNode is AuraStorage, ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    //Chainlink Vars: 
    uint256 private fee; 
    bytes32 private jobId; 

    // //Chainlink Constructor:
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
    function requestMintStatus(address addr, string calldata eventId) public {


        Chainlink.Request memory req = buildChainlinkRequest (

            jobId,
            address(this),
            this.fulfillMintStatus.selector
        );
        
        string memory url = string.concat(

            "https://us-central1-aura-3b019.cloudfunctions.net/testNode","?uid=",
            toAsciiString(addr),
            "&eventId=",
            eventId
        );

        req.add('fetchURL', url);
        sendChainlinkRequest(req, fee); 
    }

    //Chainlink Fullfill Mint Status: 
    function fulfillMintStatus (bytes32 requestId, bool _canMint, string calldata _requester, string calldata _eventId) public recordChainlinkFulfillment (requestId) {
        
        bytes32 _poapID = bytes32(bytes(_eventId));
        address _user = toAddress(_requester); 

        IDToPoap[_poapID].canMint[_user] = _canMint; 
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

//SPDX-License-Identifier: MIT

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "./AuraStorage.sol";   

pragma solidity ^0.8.12;

contract AuraCollect is AuraStorage, ERC721URIStorage {
    using Counters for Counters.Counter;

    constructor() ERC721 ("POAP Media Asset", "POAP") {}
    Counters.Counter public _tokenIds;

    event PoapCollected (
        address Collector, 
        uint256 Token,
        bytes32 ID, 
        string Name,
        bytes32[] Collections,
        string Location,
        uint256 Time
    );

    //Poap Mint Function: 
    function collectPoap (bytes32 _poapID) external {

        uint256 newTokenId = _tokenIds.current();

        //Requires:
        require (IDToPoap[_poapID].canMint[msg.sender] == true, "You are not within range of this poap.");
        require (IDToPoap[_poapID].supply >= 1, "Poap supply ran out.");   
        require (IDToPoap[_poapID].status == true, "This poap is not currently active."); 
        require (block.timestamp > IDToPoap[_poapID].startTime, "This poap has not started.");
        require (block.timestamp < IDToPoap[_poapID].endTime, "This poap has already ended."); 
        require (msg.sender != IDToPoap[_poapID].poapOwner, "You can not collect your own poap."); 

        //Check if user is invited
        if (IDToPoap[_poapID].gated == true) {
            require (IDToPoap[_poapID].invites[msg.sender] == true, "You are not invited to this poap."); 
        }

        //Minting: 
        for (uint i = 0; i <= 1; i++) {

            //Token IDs and Minting
            _tokenIds.increment();
            _safeMint(msg.sender, newTokenId);
            _setTokenURI(newTokenId, IDToPoap[_poapID].poapBaseURI);

            //Push to user mapping and poap mapping
            userPoaps[msg.sender].push(_poapID);
            userTokenIDs[msg.sender].push(newTokenId);

            IDToPoap[_poapID].poapCollectors.push(msg.sender); 
            IDToPoap[_poapID].poapTokenIDs.push(newTokenId);

            tokenIDs.push(newTokenId);  
            

            if (IDToPoap[_poapID].poapCollections.length >= 1) {

               //Check for collections
                for (uint j = 0; j <= IDToPoap[_poapID].poapCollections.length; j++) {

                    //Push to mappings
                
                    //Collection:
                    IDToCollection[IDToPoap[_poapID].poapCollections[j]].collectionCollectors.push(msg.sender); 
                    IDToCollection[IDToPoap[_poapID].poapCollections[j]].collectionTokenIDs.push(newTokenId);

                    //User:
                    userCollections[msg.sender].push(IDToPoap[_poapID].poapCollections[j]);

                    //Token: 
                    tokenInCollection[newTokenId][IDToPoap[_poapID].poapCollections[j]] = true;   
                }
            } 
            
            IDToPoap[_poapID].supply--; 
            poapsCollected++; 

            emit PoapCollected (msg.sender, newTokenId, _poapID, IDToPoap[_poapID].poapName,
            IDToPoap[_poapID].poapCollections, IDToPoap[_poapID].poapLocation, block.timestamp);          
        }
    }
}

//SPDX-License-Identifier: MIT

import "./AuraStorage.sol"; 

pragma solidity ^0.8.12;

contract AuraEdit is AuraStorage{

    modifier inviteModif (bytes32 _poapID) {
        require (IDToPoap[_poapID].poapOwner == msg.sender, "You are not the owner of this poap."); 
        require (IDToPoap[_poapID].gated == true, "This poap is not gated."); 
        require (block.timestamp < IDToPoap[_poapID].endTime, "This poap has already ended.");
        _;
    }

    //Helper Functions: ==============================================================================

    function checkMatch(bytes32 _poapID, bytes32 _collectionID) internal view returns (bool) {

        uint256 counter = 0; 

        if (IDToPoap[_poapID].poapCollections.length >= 1) {

            for (uint i = 0; i <= IDToPoap[_poapID].poapCollections.length; i++) {

                //if collectionID is not in poap collections array
                if (IDToPoap[_poapID].poapCollections[i] != _collectionID) {
                    counter++; //Increment counter

                    //if counter is equal to the amount of collections in the array
                } else if (counter == IDToPoap[_poapID].poapCollections.length) {
                    return false;  //the parameter collection ID is not the the poapCollections array
                }
            }

        } else if (IDToPoap[_poapID].poapCollections.length == 0) {
            return false; 
        }

       return true; 
    }

    function popIndex (bytes32 _poapID, bytes32 _collectionID) internal {

        //Local:
        bytes32[] memory poapArr;
        bytes32[] memory colArr;
        uint256[] memory colTokenArr;

        uint256 poapCounter = 0;
        uint256 colCounter = 0;
        uint256 tokenCounter = 0;    

        //Removes from poap struct array collections array
        for (uint i = 0; i <= IDToPoap[_poapID].poapCollections.length; i++) {

            if (IDToPoap[_poapID].poapCollections[i] != _collectionID) {

                poapCounter++;
                poapArr[poapCounter] = IDToPoap[_poapID].poapCollections[i]; //push into local array
            } 
        }

        //Removes from collection struct array poap array
        for (uint i = 0; i <= IDToCollection[_collectionID].collectionPoaps.length; i++) {

            if (IDToCollection[_collectionID].collectionPoaps[i] != _poapID) {

                colCounter++;
                colArr[colCounter] = IDToCollection[_collectionID].collectionPoaps[i]; //push into local array
            }
        }

        if (IDToPoap[_poapID].startTime <= block.timestamp) {

            for (uint i = 0; i <= IDToCollection[_collectionID].collectionTokenIDs.length; i++) {

                if (IDToPoap[_poapID].poapTokenIDs[i] != IDToCollection[_collectionID].collectionTokenIDs[i]) {

                    tokenCounter++;
                    colTokenArr[tokenCounter] = IDToCollection[_collectionID].collectionTokenIDs[i]; //push into local array
                }
            }
        }
    
        IDToPoap[_poapID].poapCollections = poapArr;
        IDToCollection[_collectionID].collectionPoaps = colArr;
        IDToCollection[_collectionID].collectionTokenIDs = colTokenArr;
    }

    //Invites: ========================================================================================

    //Add Invitations
    function addInvite (bytes32 _poapID, address[] calldata addInvites) external inviteModif(_poapID) {

        for (uint i = 0; i <= addInvites.length; i++) {

            if (IDToPoap[_poapID].invites[addInvites[i]] == false) {
                IDToPoap[_poapID].invites[addInvites[i]] = true; 
            }
        }
    }

    //Remove Invitations
    function unInvite (bytes32 _poapID, address[] calldata unInvites) external inviteModif(_poapID) {

        for (uint i = 0; i <= unInvites.length; i++) {

            if (IDToPoap[_poapID].invites[unInvites[i]] == true) {
                IDToPoap[_poapID].invites[unInvites[i]] = false; 
            }
        }
    }

    //Add - Remove: =====================================================================================

    //Add to collection 
    function addPoapToCollection (bytes32 _poapID, bytes32 _collectionID) external {

        //Requires:
        require (IDToPoap[_poapID].poapOwner == msg.sender, "You are not the owner of this poap.");
        require (IDToCollection[_collectionID].collectionOwner == msg.sender, "You are not the owner of this collection");
        require (checkMatch(_poapID, _collectionID) == false, "This poap is already in this collection");  

        //Push into struct-arrays
        IDToPoap[_poapID].poapCollections.push(_collectionID);
        IDToCollection[_collectionID].collectionPoaps.push(_poapID);

        //If poap has already started change maping values for tokens and users
        if (IDToPoap[_poapID].startTime <= block.timestamp) {

            //User Collection Mapping
            for (uint i = 0; i <= IDToCollection[_collectionID].collectionCollectors.length; i++) {

                //Check if user is already in collection, if not push them into the array
                if (IDToPoap[_poapID].poapCollectors[i] != IDToCollection[_collectionID].collectionCollectors[i]) {

                    IDToCollection[_collectionID].collectionCollectors.push(IDToPoap[_poapID].poapCollectors[i]);
                } 

                //Add collectionID to user collections mapping
                userCollections[IDToPoap[_poapID].poapCollectors[i]].push(_collectionID); 
            }

            //Token IDs mapping
            for (uint i = 0; i <= IDToPoap[_poapID].poapTokenIDs.length; i++) {

                //Push current index tokenID into collection struct-array
                IDToCollection[_collectionID].collectionTokenIDs.push(IDToPoap[_poapID].poapTokenIDs[i]);

                //set token mapping
                //tokenAffiliation[IDToPoap[_poapID].poapTokenIDs[i]][_poapID].push(_collectionID);
                tokenInCollection[IDToPoap[_poapID].poapTokenIDs[i]][_collectionID] = true;  
            }
        }  
    }


    function removePoapFromCollection (bytes32 _poapID, bytes32 _collectionID) external {

        //Requires:
        require (IDToPoap[_poapID].poapOwner == msg.sender, "You are not the owner of this poap.");
        require (IDToCollection[_collectionID].collectionOwner == msg.sender, "You are not the owner of this collection");
        require (checkMatch(_poapID, _collectionID) == true, "This poap is not in this collection");

        
        
    }     
}
