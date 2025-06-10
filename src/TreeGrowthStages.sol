// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

<<<<<<< HEAD
import {NFTCollection} from "./NFTCollection.sol";

contract TreeGrowthStages is NFTCollection {
    uint256 public constant wateringCost = 0.0001 ether;
    uint256 public constant wateringCooldown = 1 days;
    address public initialOwner;

    event treeGrowthCalculation(
        uint256 tokenId,
        uint8 growthStage,
        uint16 wateringCount
    );

    constructor(address whitelistContract) NFTCollection(whitelistContract) {
=======
import {TreeNFTCollection} from "./TreeNFTCollection.sol";

contract TreeGrowthStages is TreeNFTCollection {
    uint256 public constant wateringCost = 0.0004 ether;
    uint256 public constant wateringCooldown = 1 days;
    address public initialOwner;

    event treeGrowthCalculation(uint256 tokenId, uint8 growthStage, uint16 wateringCount);
    event metaDataUpdate(uint256 tokenId);
    constructor(address whitelistContract) TreeNFTCollection(whitelistContract) {
>>>>>>> 19a2ec4 (working on withered tree)
        initialOwner == msg.sender;
    }

    function wateringTree(uint256 tokenId) external payable nonReentrant {
        require(
            ownerOf(tokenId) == msg.sender,
            "only owner can water the tree"
        );
        TreeData storage tree = treeData[tokenId];
<<<<<<< HEAD
<<<<<<< HEAD
        require(balanceOf(msg.sender) >= wateringCost, "insufficient payment");
        require(
            block.timestamp >= tree.lastWateredTimestamp + wateringCooldown,
            "tree was already watered"
        );
=======
        require(msg.value >= wateringCost, "insufficient payment");
        require(tree.lastWateredTimestamp == 0 || block.timestamp >= tree.lastWateredTimestamp + wateringCooldown, "tree was already watered");
>>>>>>> d7a212c (fix: all tests passed, start working on nft collection)

        uint16 newWateringCount = tree.wateringCount + 1;
<<<<<<< HEAD
        uint8 calculatedNewStage = calculateGrowthStages(
            tree.plantedTimestamp,
            newWateringCount
        );

        uint8 checkIfStageIsUpdated = calculatedNewStage > tree.growthStage
            ? calculatedNewStage
            : tree.growthStage;
=======
        uint8 calculatedNewStage = calculateGrowthStages(tree.plantedTimestamp, newWateringCount);
        uint8 checkIfStageIsUpdated = calculatedNewStage > tree.growthStage ? calculatedNewStage : tree.growthStage;
>>>>>>> d7a212c (fix: all tests passed, start working on nft collection)

        tree.lastWateredTimestamp = block.timestamp;
        tree.wateringCount = newWateringCount;
        tree.growthStage = checkIfStageIsUpdated;

        emit treeGrowthCalculation(
            tokenId,
            checkIfStageIsUpdated,
            newWateringCount
        );
=======
        require(msg.value >= wateringCost, "insufficient payment");
        require(tree.lastWateredTimestamp == 0 || block.timestamp >= tree.lastWateredTimestamp + wateringCooldown, "tree was already watered");

        uint16 newWateringCount = tree.wateringCount + 1;
        uint8 calculatedNewStage = calculateGrowthStages(tree.plantedTimestamp, newWateringCount);

        tree.lastWateredTimestamp = block.timestamp;
        tree.wateringCount = newWateringCount;
        if(tree.growthStage != calculatedNewStage){
            emit metaDataUpdate(tokenId);
        }
        tree.growthStage = calculatedNewStage;

        emit treeGrowthCalculation(tokenId, tree.growthStage, newWateringCount);
>>>>>>> 19a2ec4 (working on withered tree)
    }

    function calculateGrowthStages(
        uint256 plantedTimestamp,
        uint16 wateringCount
    ) internal view returns (uint8 newStage) {
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

    //if the tree is not watered for 5 days, the contract will mint a withered tree
    function CheckIfTreeIsWatered(uint256 tokenId) internal view returns (uint8 newStage){
        TreeData storage tree = treeData[tokenId];
        if(tree.plantedTimestamp + 5 days < tree.lastWateredTimestamp){
            newStage = 5;
        }

    }
}
