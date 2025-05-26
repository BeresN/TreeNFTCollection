// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./NFTCollection.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract TreeGrowthStages is ReentrancyGuard {
    uint256 public constant wateringCost = 0.0001 ether;
    uint256 public constant wateringCooldown = 1 days;
    NFTCollection immutable nftContract;
    NFTCollection.TreeData[] internal treeData;

    event treeGrowthStageUpdate(uint256 tokenId, uint8 newStage);
    event treeWatered(uint256 tokenId, uint8 growthStage, uint256 wateringCount);

    constructor(address _nftContract){
        require(_nftContract != address(0), "cannot be 0 address");
        nftContract = NFTCollection(_nftContract);
    }

    function wateringTree(uint256 tokenId) external payable nonReentrant(){
        NFTCollection.TreeData storage tree = treeData[tokenId];
        require(nftContract.ownerOf(tokenId) == msg.sender, "only owner can water the tree");
        require(msg.value >= wateringCost, "insufficient payment");
        require(block.timestamp >= tree.lastWateredTimestamp + wateringCooldown, "tree was already watered");

        tree.lastWateredTimestamp = block.timestamp;
        tree.wateringCount++;

        calculateGrowthStages(tokenId);

        emit treeWatered(tokenId, tree.growthStage, tree.wateringCount);
    }

    function calculateGrowthStages(uint256 tokenId) public{
        NFTCollection.TreeData storage tree = treeData[tokenId];
        uint256 ageInDays = (block.timestamp - tree.plantedTimestamp) / 1 days;

        uint8 newStage;

        if (ageInDays >= 365 && tree.wateringCount >= 100) {
        newStage = 4; // Ancient tree (1+ year, 100+ waterings)
        } else if (ageInDays >= 180 && tree.wateringCount >= 50) {
            newStage = 3; // Mature tree (6+ months, 50+ waterings)
        } else if (ageInDays >= 30 && tree.wateringCount >= 15) {
            newStage = 2; // Young tree (1+ month, 15+ waterings)
        } else if (ageInDays >= 7 && tree.wateringCount >= 5) {
            newStage = 1; // Sapling (1+ week, 5+ waterings)
        } else {
            newStage = 0; // Seedling
        }

        if(newStage > tree.growthStage){
            tree.growthStage = newStage;
            emit treeGrowthStageUpdate(tokenId, newStage);
        }
        
    }
}
