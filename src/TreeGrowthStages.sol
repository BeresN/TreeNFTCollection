// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {NFTCollection} from "./NFTCollection.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract TreeGrowthStages is ReentrancyGuard, NFTCollection {
    uint256 public constant wateringCost = 0.0001 ether;
    uint256 public constant wateringCooldown = 1 days;

    event treeGrowthCalculation(uint256 tokenId, uint8 growthStage, uint16 wateringCount);

    constructor(address initialOwner, address whitelistContract) NFTCollection(initialOwner, whitelistContract) {
    }

    function wateringTree(uint256 tokenId) external payable nonReentrant(){
        require(ownerOf(tokenId) == msg.sender, "only owner can water the tree");
        TreeData storage tree = treeData[tokenId];
        require(msg.value >= wateringCost, "insufficient payment");
        require(block.timestamp >= tree.lastWateredTimestamp + wateringCooldown, "tree was already watered");

        tree.lastWateredTimestamp = block.timestamp;
        uint16 newWateringCount = tree.wateringCount + 1;
        uint8 calculatedNewStage = calculateGrowthStages( 
            tree.plantedTimestamp,
            newWateringCount 
        );

        uint8 checkIfStageIsUpdated = calculatedNewStage > tree.growthStage ? calculatedNewStage : tree.growthStage;

        this.updateTreeData(
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
