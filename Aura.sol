//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol"; 

//Tested with mappings insted of array structs

contract AURA is ERC721URIStorage, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    constructor() ERC721("AURA Media Asset", "AURA") {}

    
    uint256 public totalPoapsCreated;
    uint256 public totalPoapsCollected; 

    string[] public poapNames; 
    
    //Structs & Mappings  ====================================================

    Poap[] public poaps;

    struct Poap {

        bytes32 poapID;

        address owner; 

        string name;
        string description;
        string location;
        string baseURI;

        uint256 timeStart; 
        uint256 timeEnd;

        uint256 maxCollectors;

        bool inviteOnly;
        bool status;
    }


    mapping (bytes32 => Poap) public IDToPoap;  //poap ID => struct 
    mapping (bytes32 => address[]) public poapInvites;
    mapping (bytes32 => address[]) public poapCollectors;
   

    mapping (address => mapping (bytes32 => bool)) public collectorProximityStatus; //collector addr => poap ID => proximity status
    mapping (address => mapping (bytes32 => bool)) public collectorMinted; //collector addr => poap ID => mint status
    
    mapping (address => bytes32[]) public collectorPoaps; //address => all poap IDs they have collected from

    mapping(address => uint256) public userPoapsCreated;
  

    //Events ====================================================================================================================

    event poapCreated (

        bytes32 poapID,
        address owner,

        string name,
        string description,
        string location,
        string baseURI,

        uint256 creationTime,
        uint256 startTime,
        uint256 endTime,

        uint256 maxCollectors
    );

    event poapCollected (

        bytes32 poapID,
        address collector,

        uint256 collectTime,
        uint256 tokenId,

        string name,
        string description
    );
     
    //Helper Functions ===========================================================================================================

    function hashIDStr (string calldata str) internal view returns (bytes32) { //collison hash 
        return keccak256(abi.encodePacked(str, block.timestamp, block.difficulty)); 
    }

 
    function checkNameRepeat (string memory str) internal view returns (bool) {
        
        for (uint i; i < poapNames.length; i++) { //hashes (_name) and index of poapNames[] and compares

            if (keccak256(abi.encodePacked(str)) == keccak256(abi.encodePacked(poapNames[i]))) {
               return true; 
            }
        }

        return false; 
    }

    //Check invite 
    function checkInviteStatus (bytes32 _poapID, address addr) public view returns (bool) {

        for (uint i = 0; i < poapInvites[_poapID].length; i++) {

            if (poapInvites[_poapID][i] == addr) {
                return true;
            }
        }

        return false;
    }

    //Modifiers =============================================================================================================


    //Primary Functions =============================================================================================================

    //Create POAP Function - stack too deep is awful 
    //_nameDesc[0] = name | _nameDesc[1] = description | _times[0] = timeStart | _times[1] = timeEnd
    function createPoap (string memory _baseURI, string[] calldata _nameDesc, string calldata _location, address[] calldata _invites, uint256[] calldata _times, uint256 _maxCollectors) external {

        //String Requires:
        require (bytes(_nameDesc[0]).length <= 50, "Err 1"); 
        require (checkNameRepeat(_nameDesc[0]) == false, "Err 2");   
        require (bytes(_nameDesc[1]).length <= 280, "Err 3"); 

        //Time Requires:
        require(_times[0] < _times[1], "Err 4"); 
        require(_times[0] > block.timestamp, "Err 5"); 

        bytes32 poapID = hashIDStr(_nameDesc[0]); 

        Poap storage newPoap = IDToPoap[poapID]; 

        newPoap.poapID = poapID;
        

        //Strings 
        newPoap.owner = msg.sender;
        newPoap.name = _nameDesc[0];
        newPoap.description = _nameDesc[1];
        newPoap.location = _location; 
        newPoap.baseURI = _baseURI; 
        
        //Uint & Bytes
        newPoap.timeStart = _times[0]; //indexing times in an aray because stack is too deep otherwise
        newPoap.timeEnd = _times[1];
        newPoap.maxCollectors = _maxCollectors; 

        //Whitelist / Invitees
        newPoap.inviteOnly = false; //Auto set to false to avoid else statement

        if (_invites.length > 0) {

            newPoap.inviteOnly = true;

            poapInvites[poapID] = _invites;  
        }
        
        newPoap.status = true; 

        userPoapsCreated[msg.sender]++; //user created mapping (addr => uint256)
        poapNames.push(newPoap.name);

        totalPoapsCreated++;
         
        emit poapCreated (newPoap.poapID, newPoap.owner, newPoap.name, newPoap.description, newPoap.location, newPoap.baseURI, 
        block.timestamp, newPoap.timeStart, newPoap.timeEnd, newPoap.maxCollectors);
    }

    //Collect POAP Function
    function collectPoap (bytes32 _poapID) external {

        //Collector Requires
        require(collectorProximityStatus[msg.sender][_poapID], "Err 6"); 
        require(!collectorMinted[msg.sender][_poapID], "Err 7"); 

        if (IDToPoap[_poapID].inviteOnly == true) {
            require(checkInviteStatus(_poapID, msg.sender) == true, "Err 8");
        }

        //POAP Requires
        require(IDToPoap[_poapID].owner != msg.sender, "Err 9"); 
        require(IDToPoap[_poapID].status == true, "Err 10");
        require(block.timestamp < IDToPoap[_poapID].timeEnd && block.timestamp > IDToPoap[_poapID].timeStart, "Err 11");
        require(poapCollectors[_poapID].length < IDToPoap[_poapID].maxCollectors, "Err 12");

       
 
        uint256 newTokenId = _tokenIds.current();

        for (uint i = 0; i < 1; i++) {

            //Minting:
            _tokenIds.increment();
            _safeMint(msg.sender, newTokenId);
            _setTokenURI(newTokenId, IDToPoap[_poapID].baseURI);

            //Mapping Assignments
            collectorMinted[msg.sender][_poapID] = true; //Sets collector mint status
            collectorPoaps[msg.sender].push(_poapID); //Pushes POAPID into mapping

            poapCollectors[_poapID].push(msg.sender);  //Pushes msg.sender addr into POAP collectors mapping

            totalPoapsCollected++; 
        }

        emit poapCollected (IDToPoap[_poapID].poapID, msg.sender, block.timestamp, newTokenId, 
        IDToPoap[_poapID].name, IDToPoap[_poapID].description);
    }

    //Secondary Functions =============================================================================================================

    //Delete Poap
    function deletePoap (bytes32 _poapID, bool _status) external {
        
        require(IDToPoap[_poapID].owner == msg.sender, "Err 13"); //Requiring that msg.sender is the owner
        require(block.timestamp > IDToPoap[_poapID].timeStart, "Err 14");
        require(block.timestamp < IDToPoap[_poapID].timeEnd, "Err 15"); 

        IDToPoap[_poapID].status = _status;  //Prompts owner to pause / unpause poap status
    }

    //Uninvite 
    function unInvite (bytes32 _poapID, address[] calldata unInvites) external {

        require(IDToPoap[_poapID].owner == msg.sender, "Err 16");
        require(poapInvites[_poapID].length >= unInvites.length, "Err 17"); 

        require(IDToPoap[_poapID].inviteOnly == true, "Err 18");
        require(block.timestamp < IDToPoap[_poapID].timeEnd, "Err 19");

        for (uint i = 0; i < unInvites.length; i++) {

            if (poapInvites[_poapID][i] == unInvites[i]) {
                delete poapInvites[_poapID][i];
            }
        }
    }
    
    //Add invite
    function addInvite (bytes32 _poapID, address[] calldata addedInvites) external {

        require(IDToPoap[_poapID].owner == msg.sender, "Err 20");
        require(IDToPoap[_poapID].inviteOnly == true, "Err 21");
        require(block.timestamp < IDToPoap[_poapID].timeEnd, "Err 22");

        for (uint256 i = 0; i < addedInvites.length; i++) {

            if (poapInvites[_poapID][i] == addedInvites[i]) {
                poapInvites[_poapID].push(addedInvites[i]);
            }
        }

    }



    //Getter Functions =============================================================================================================

    //POAP -----------------------------------------------------------------------------------
    function getPoapCollectors (bytes32 _poapID) public view returns (address[] memory) {
        return poapCollectors[_poapID];  
    }

    function getPoapCollectorsNum (bytes32 _poapID) public view returns (uint256) {
        return poapCollectors[_poapID].length;
    }
    
    function getPoapStatus (bytes32 _poapID) public view returns (bool) {
        return IDToPoap[_poapID].status;
    }

    function getPoapBaseURI (bytes32 _poapID) public view returns (string memory) {
        return IDToPoap[_poapID].baseURI; 
    }
    

    //User -----------------------------------------------------------------------------------
    function getUserPoapsIDs(address _user) public view returns (bytes32[] memory) {
        return collectorPoaps[_user];
    }

    
    function getUserCollectedNum(address _user) public view returns (uint256) {
        return collectorPoaps[_user].length;
    }
    
    
    function getUserCreatedNum(address _user) public view returns (uint256) {
        return userPoapsCreated[_user]; 
    }

}

