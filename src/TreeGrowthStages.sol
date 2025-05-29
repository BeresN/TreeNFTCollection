// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./NFTCollection.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract TreeGrowthStages is ReentrancyGuard {
    uint256 public constant wateringCost = 0.0001 ether;
    uint256 public constant wateringCooldown = 1 days;
    NFTCollection immutable nftContract;

    event treeGrowthCalculation(uint256 tokenId, uint8 growthStage, uint16 wateringCount);

    constructor(address _nftContract){
        require(_nftContract != address(0), "cannot be 0 address");
        nftContract = NFTCollection(_nftContract);
    }

    function wateringTree(uint256 tokenId) external payable nonReentrant(){
        (
            uint256 plantedTimestamp,
            uint256 lastWateredTimestamp,
            uint8 growthStage,
            uint16 wateringCount
        ) = nftContract.getTreeData(tokenId);
        
        require(nftContract.ownerOf(tokenId) == msg.sender, "only owner can water the tree");
        require(msg.value <= wateringCost, "insufficient payment");
        require(block.timestamp >= lastWateredTimestamp + wateringCooldown, "tree was already watered");

        lastWateredTimestamp = block.timestamp;
        uint16 newWateringCount = wateringCount + 1;
        uint8 calculatedNewStage = calculateGrowthStages( 
            plantedTimestamp,
            newWateringCount 
        );

        uint8 checkIfStageIsUpdated = calculatedNewStage > growthStage ? calculatedNewStage : growthStage;

        nftContract.updateTreeData(
            tokenId,
            newWateringCount,
            checkIfStageIsUpdated
        );

        emit treeGrowthCalculation(tokenId, checkIfStageIsUpdated, newWateringCount);
    }

    function calculateGrowthStages(
        uint256 plantedTimestamp,
        uint16 wateringCount
        ) internal view returns(uint8 newStage){

        uint256 ageInDays = (block.timestamp - plantedTimestamp) / 1 days;

        if (ageInDays >= 365 && wateringCount >= 100) {
        newStage = 4; // Ancient tree (1+ year, 100+ waterings)
        } else if (ageInDays >= 180 && wateringCount >= 50) {
            newStage = 3; // Mature tree (6+ months, 50+ waterings)
        } else if (ageInDays >= 30 && wateringCount >= 15) {
            newStage = 2; // Young tree (1+ month, 15+ waterings)
        } else if (ageInDays >= 7 && wateringCount >= 5) {
            newStage = 1; // Sapling (1+ week, 5+ waterings)
        } else {
            newStage = 0; // Seedling
        }

    }
}
