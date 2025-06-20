// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TreeNFTCollection} from "./TreeNFTCollection.sol";

contract TreeGrowthStages is TreeNFTCollection {
//tracking if address was already rewarded after reaching next stage
mapping(uint256 => mapping(uint8 => bool)) stageRewardsClaimed;

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
        initialOwner = msg.sender;
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
        if (tree.growthStage != calculatedNewStage) {
            emit metaDataUpdate(tokenId);
        }
        tree.growthStage = calculatedNewStage;
        require(tree.growthStage != 0, "Tree is withered, revive first");

        emit treeGrowthCalculation(tokenId, tree.growthStage, newWateringCount);
    }

    function mintNextStageToken(uint256 tokenId) external payable nonReentrant returns(uint256 newTokenId){
        TreeData storage tree = treeData[tokenId];
        if(tree.treeType == TreeType.Normal){
            newTokenId = reservedTokensClaimed++;

            tree.plantedTimestamp = block.timestamp;
            tree.lastWateredTimestamp = 0;
            tree.growthStage+1;
            tree.wateringCount = 0;

            _safeMint(msg.sender, newTokenId);
        }
        else{

        }

    }
    
      function reviveWitheredTree(uint256 tokenId) external payable nonReentrant{
        require(ownerOf(tokenId) == msg.sender, "not a owner");
        require(isTreeWithered(tokenId), "tree is not withered");
        require(msg.value >= wateringCost * 5, "insufficient amount");

        TreeData storage tree = treeData[tokenId];
        tree.lastWateredTimestamp = block.timestamp;
        tree.growthStage = 1;

        emit treeGrowthCalculation(
            tokenId,
            tree.growthStage,
            tree.wateringCount
        );
    }

    function calculateGrowthStages(
        uint256 tokenId,
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
        } else {
            newStage = 1; // Sapling basic nft
        }

        if (isTreeWithered(tokenId)) {
            newStage = 0;
        }
    }


    function isTreeWithered(uint256 tokenId) internal view returns (bool) {
        TreeData storage tree = treeData[tokenId];

        if (tree.lastWateredTimestamp == 0) {
            return false;
        }
        return (tree.plantedTimestamp + 6 days < tree.lastWateredTimestamp);
    }

}
