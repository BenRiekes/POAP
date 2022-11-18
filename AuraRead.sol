//SPDX-License-Identifier: MIT

import "https://github.com/BenRiekes/Smart-Contracts/blob/main/AuraStorage.sol"; 

pragma solidity ^0.8.12;

contract AuraRead is AuraStorage {

    //Collection getters: 
    function getCollectionDetails (bytes32 _collectionID) external view returns (address, string memory, string memory) {
        return (IDToCollection[_collectionID].collectionOwner, IDToCollection[_collectionID].collectionName, 
        IDToCollection[_collectionID].collectionDesc); 
    }

    function getCollectionStats (bytes32 _collectionID) external view returns (address[] memory, bytes32[] memory, uint256[] memory, uint256[] memory) {

        uint256[] memory collectionStats;
        collectionStats[0] = IDToCollection[_collectionID].collectionCollectors.length;
        collectionStats[1] = IDToCollection[_collectionID].collectionPoaps.length; 
        collectionStats[2] = IDToCollection[_collectionID].collectionTokenIDs.length; 

        return (IDToCollection[_collectionID].collectionCollectors, IDToCollection[_collectionID].collectionPoaps,
        IDToCollection[_collectionID].collectionTokenIDs, collectionStats);
    }

    
    //Poap Getters:
    function getPoapDetails (bytes32 _poapID) external view returns (address, string[] memory, uint256[] memory, bool[] memory) {

        string[] memory poapStringDetails;
        poapStringDetails[0] = IDToPoap[_poapID].poapName;
        poapStringDetails[1] = IDToPoap[_poapID].poapDesc;
        poapStringDetails[2] = IDToPoap[_poapID].poapLocation; 
        poapStringDetails[3] = IDToPoap[_poapID].poapBaseURI; 

        uint256[] memory poapUintDetails; 
        poapUintDetails[0] = IDToPoap[_poapID].startTime;
        poapUintDetails[1] = IDToPoap[_poapID].endTime;
        poapUintDetails[2] = IDToPoap[_poapID].supply; 

        bool[] memory poapBoolDetails;
        poapBoolDetails[0] = IDToPoap[_poapID].gated;
        poapBoolDetails[1] = IDToPoap[_poapID].status; 

        return (IDToPoap[_poapID].poapOwner, poapStringDetails, poapUintDetails, poapBoolDetails); 
    }

    function getPoapStats (bytes32 _poapID) external view returns (address[] memory, bytes32[] memory, uint256[] memory, uint256[] memory) {

        uint256[] memory poapStats;
        poapStats[0] = IDToPoap[_poapID].poapCollectors.length; 
        poapStats[1] = IDToPoap[_poapID].poapCollections.length; 
        poapStats[2] = IDToPoap[_poapID].poapTokenIDs.length; 

        return (IDToPoap[_poapID].poapCollectors, IDToPoap[_poapID].poapCollections, IDToPoap[_poapID].poapTokenIDs, poapStats); 
    }


    //User getters: 
    function getPoapInviteStatus (address _user, bytes32 _poapID) external view returns (bool) {
        return IDToPoap[_poapID].invites[_user];  
    }

    //User Tokens From Collection
    function getUserCollectionTokens (address _user, bytes32 _collectionID) external view returns (uint256[] memory) {

        uint256[] memory collectionTokens; 
        uint256 counter = 0; 

        for (uint i = 0; i <= IDToCollection[_collectionID].collectionTokenIDs.length; i++) {

            if (IDToCollection[_collectionID].collectionTokenIDs[i] == userTokenIDs[_user][i]) {
                counter++;
                collectionTokens[counter] = userTokenIDs[_user][i]; 
            }
        }

        return collectionTokens; 
    }

}
