// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TreeNFTCollection} from "./TreeNFTCollection.sol";

contract TreeGrowthStages is TreeNFTCollection {
    uint256 public constant wateringCost = 0.0004 ether;
    uint256 public constant wateringCooldown = 1 days;
    address public initialOwner;

    event treeGrowthCalculation(
        uint256 tokenId,
        uint8 growthStage,
        uint16 wateringCount
    );
    event metaDataUpdate(uint256 tokenId);

    constructor(
        address whitelistContract
    ) TreeNFTCollection(whitelistContract) {
        initialOwner == msg.sender;
    }

    function wateringTree(uint256 tokenId) external payable nonReentrant {
        require(
            ownerOf(tokenId) == msg.sender,
            "only owner can water the tree"
        );
        TreeData storage tree = treeData[tokenId];
        require(msg.value >= wateringCost, "insufficient payment");
        require(
            tree.lastWateredTimestamp == 0 ||
                block.timestamp >= tree.lastWateredTimestamp + wateringCooldown,
            "tree was already watered"
        );

        uint16 newWateringCount = tree.wateringCount + 1;
        uint8 calculatedNewStage = calculateGrowthStages(
            tokenId,
            tree.plantedTimestamp,
            newWateringCount
        );

        tree.lastWateredTimestamp = block.timestamp;
        tree.wateringCount = newWateringCount;
        tree.growthStage = calculatedNewStage;

        require(tree.growthStage != 0, "Tree is withered, revive first");

        emit treeGrowthCalculation(tokenId, tree.growthStage, newWateringCount);
    }

    function calculateGrowthStages(
        uint256 tokenId,
        uint256 plantedTimestamp,
        uint16 wateringCount
    ) internal view returns (uint8 newStage) {
        uint256 ageInDays = (block.timestamp - plantedTimestamp) / 1 days;

        if (ageInDays >= 100 && wateringCount >= 100) {
            newStage = 4; // Ancient tree (1+ year, 100+ waterings)
        } else if (ageInDays >= 50 && wateringCount >= 50) {
            newStage = 3; // Mature tree (6+ months, 50+ waterings)
        } else if (ageInDays >= 30 && wateringCount >= 30) {
            newStage = 2; // Young tree (1+ month, 15+ waterings)
        } else {
            newStage = 1; // Sapling (1+ week, 5+ waterings)
        }

        if (isTreeWithered(tokenId) == true) {
            newStage = 0;
        }
    }

    function getTreeData(
        uint256 tokenId
    )
        external
        view
        override
        returns (
            uint256 plantedTimestamp,
            uint256 lastWateredTimestamp,
            uint8 growthStage,
            uint16 wateringCount
        )
    {
        require(ownerOf(tokenId) != address(0), "token not minted yet");
        TreeData storage tree = treeData[tokenId];

        uint8 currentStage = isTreeWithered(tokenId) ? 0 : tree.growthStage;
        return (
            tree.plantedTimestamp,
            tree.lastWateredTimestamp,
            currentStage,
            tree.wateringCount
        );
    }

    //if the tree is not watered for 5 days, the contract will mint a withered tree
    function isTreeWithered(uint256 tokenId) internal view returns (bool) {
        TreeData storage tree = treeData[tokenId];

        if (tree.lastWateredTimestamp == 0) {
            return false;
        }
        return (tree.plantedTimestamp + 6 days < tree.lastWateredTimestamp);
    }

    function reviveWitheredTree(uint256 tokenId) external payable {
        require(ownerOf(tokenId) == msg.sender);
        require(isTreeWithered(tokenId) == true);
        require(msg.value >= wateringCost * 5);

        TreeData storage tree = treeData[tokenId];
        tree.lastWateredTimestamp = block.timestamp;
        tree.growthStage = 1;

        emit treeGrowthCalculation(
            tokenId,
            tree.growthStage,
            tree.wateringCount
        );
    }
}
