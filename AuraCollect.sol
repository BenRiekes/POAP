//SPDX-License-Identifier: MIT

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/BenRiekes/Smart-Contracts/blob/main/AuraStorage.sol";   

pragma solidity ^0.8.12;

contract AuraCollect is AuraStorage, ERC721URIStorage {
    using Counters for Counters.Counter;

    constructor() ERC721 ("POAP Media Asset", "POAP") {}
    Counters.Counter public _tokenIds;

    //Events: ===========================================================================================

    event PoapCollected (
        bytes32 indexed PoapID,
        bytes32[] PoapCollections, 
        string PoapName,
        string PoapLocation,
        address PoapCollector,  
        uint256 TokenID,
        uint256 TimeOfCollection
    );

    //Primary Functions: ===================================================================================

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

            emit PoapCollected (_poapID, IDToPoap[_poapID].poapCollections, IDToPoap[_poapID].poapName,
            IDToPoap[_poapID].poapLocation, msg.sender, newTokenId, block.timestamp);           
        }
    }
}
