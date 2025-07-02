// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {TreeNFTCollection} from "./TreeNFTCollection.sol";

contract TreeGrowthStages is TreeNFTCollection {
    uint256 public constant wateringCost = 0.0004 ether;
    uint256 public constant wateringCooldown = 1 days;
    //time after which the tree is withered
    uint256 public constant witherTime = 5 days;
    address public immutable initialOwner;

    event TreeGrowthCalculation(
        uint256 tokenId,
        uint256 plantedTimestamp,
        uint8 growthStage,
        uint16 wateringCount
    );
    event NextStageNFTMinted(address indexed to, uint256 newTokenId);

    constructor(
        address whitelistContract
    ) TreeNFTCollection(whitelistContract) {
        initialOwner = msg.sender;
    }

    function wateringTree(uint256 tokenId) external payable {
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
        require(calculatedNewStage != 0, "Tree is withered, revive first");

        tree.lastWateredTimestamp = block.timestamp;
        tree.wateringCount = newWateringCount;

        if (tree.growthStage != calculatedNewStage) {
            mintNextStageToken(tokenId);
        }
        tree.growthStage = calculatedNewStage;
        emit TreeGrowthCalculation(
            tokenId,
            tree.plantedTimestamp,
            tree.growthStage,
            newWateringCount
        );
    }

    function mintNextStageToken(
        uint256 tokenId
    ) public payable nonReentrant returns (uint256 newTokenId) {
        require(ownerOf(tokenId) == msg.sender, "not a owner");
        require(isMinted[msg.sender] == false, "address already minted");
        isMinted[msg.sender] = true;

        TreeData storage originalTree = treeData[tokenId];
        uint8 newStage = calculateGrowthStages(
            tokenId,
            originalTree.plantedTimestamp,
            originalTree.wateringCount
        );

        newTokenId = reservedTokensClaimed + 1;
        reservedTokensClaimed++;

        // Set tree data for the new token with same type but new stage
        treeData[newTokenId] = TreeData({
            treeType: originalTree.treeType,
            plantedTimestamp: originalTree.plantedTimestamp,
            lastWateredTimestamp: 0,
            growthStage: newStage,
            wateringCount: originalTree.wateringCount
        });

        _safeMint(msg.sender, newTokenId);
        emit NextStageNFTMinted(msg.sender, newTokenId);
    }

    function reviveWitheredTree(uint256 tokenId) external payable nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "not a owner");
        if (!isTreeWithered(tokenId)) {
            return;
        }
        require(msg.value >= wateringCost * 5, "insufficient amount");

        TreeData storage tree = treeData[tokenId];
        tree.lastWateredTimestamp = block.timestamp;
        tree.growthStage = 1;

        emit TreeGrowthCalculation(
            tokenId,
            tree.plantedTimestamp,
            tree.growthStage,
            tree.wateringCount
        );
    }

    function calculateGrowthStages(
        uint256 tokenId,
        uint256 plantedTimestamp,
        uint16 wateringCount
    ) internal view returns (uint8 newStage) {
        if (isTreeWithered(tokenId)) {
            return newStage = 0;
        }
        uint256 ageInDays = (block.timestamp - plantedTimestamp) / 1 days;

        if (ageInDays >= 120 && wateringCount >= 50) {
            newStage = 4; // Ancient tree (3+ months, 50+ waterings)
        } else if (ageInDays >= 60 && wateringCount >= 30) {
            newStage = 3; // Mature tree (2+ months, 50+ waterings)
        } else if (ageInDays >= 30 && wateringCount >= 15) {
            newStage = 2; // Young tree (1+ month, 15+ waterings)
        } else {
            newStage = 1; // Sapling basic nft
        }
    }

    function _calculateMetadataIdForNextStage(
        uint256 tokenId
    ) public view returns (uint256) {
        TreeData storage originalTree = treeData[tokenId];

        uint256 baseTokenId;
        if (originalTree.treeType == TreeType.Summer) {
            baseTokenId = 1;
        } else if (originalTree.treeType == TreeType.Snow) {
            baseTokenId = 5;
        } else if (originalTree.treeType == TreeType.Autumn) {
            baseTokenId = 9;
        }
        uint256 calculateStage = calculateGrowthStages(
            tokenId,
            originalTree.plantedTimestamp,
            originalTree.wateringCount
        );

        return baseTokenId + calculateStage - 1;
    }

    function isTreeWithered(uint256 tokenId) internal view returns (bool) {
        TreeData storage tree = treeData[tokenId];

        if (tree.lastWateredTimestamp == 0) {
            return false;
        }
        return (block.timestamp > tree.lastWateredTimestamp + witherTime);
    }
}
