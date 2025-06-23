// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TreeNFTCollection} from "./TreeNFTCollection.sol";

contract TreeGrowthStages is TreeNFTCollection {
    //tracking if address was already rewarded after reaching next stage
    mapping(uint256 => mapping(uint8 => bool)) stageRewardsClaimed;

    uint256 public constant wateringCost = 0.0004 ether;
    uint256 public constant wateringCooldown = 1 days;
    //nextTokenId = 6, because the sprout nfts are whitelisted to maximum 5 nfts.
    uint8 public nextTokenId = 6;
    address public immutable initialOwner;

    event treeGrowthCalculation(uint256 tokenId,uint256 plantedTimestamp, uint8 growthStage, uint16 wateringCount);
    event NextStageNFTMinted(address indexed to, uint256 newTokenId);

    constructor(address whitelistContract) TreeNFTCollection(whitelistContract) {
        initialOwner = msg.sender;
    }

    function wateringTree(uint256 tokenId) external payable  {
        require(ownerOf(tokenId) == msg.sender, "only owner can water the tree");
        TreeData storage tree = treeData[tokenId];
        require(msg.value >= wateringCost, "insufficient payment");
        require(
            tree.lastWateredTimestamp == 0 || block.timestamp >= tree.lastWateredTimestamp + wateringCooldown,
            "tree was already watered"
        );

        uint16 newWateringCount = tree.wateringCount + 1;
        uint8 calculatedNewStage = calculateGrowthStages(tokenId, tree.plantedTimestamp, newWateringCount);

        tree.lastWateredTimestamp = block.timestamp;
        tree.wateringCount = newWateringCount;
        if (tree.growthStage != calculatedNewStage) {
            mintNextStageToken(tokenId);
        }
        tree.growthStage = calculatedNewStage;
        require(tree.growthStage != 0, "Tree is withered, revive first");

        emit treeGrowthCalculation(tokenId, tree.plantedTimestamp, tree.growthStage, newWateringCount);
    }

    function mintNextStageToken(uint256 tokenId) public payable nonReentrant returns (uint256 newTokenId) {
        require(ownerOf(tokenId) == msg.sender, "not a owner");
        TreeData storage tree = treeData[tokenId];
        require(!stageRewardsClaimed[tokenId][tree.growthStage], "already minted next stage token");

        newTokenId = nextTokenId++;
        tree.lastWateredTimestamp = 0;
        _safeMint(msg.sender, newTokenId);
        emit NextStageNFTMinted(msg.sender, newTokenId);
    }

    function reviveWitheredTree(uint256 tokenId) external payable nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "not a owner");
        require(isTreeWithered(tokenId), "tree is not withered");
        require(msg.value >= wateringCost * 5, "insufficient amount");

        TreeData storage tree = treeData[tokenId];
        tree.lastWateredTimestamp = block.timestamp;
        tree.growthStage = 1;

        emit treeGrowthCalculation(tokenId,tree.plantedTimestamp, tree.growthStage, tree.wateringCount);
    }

    function calculateGrowthStages(uint256 tokenId, uint256 plantedTimestamp, uint16 wateringCount)
        internal
        view
        returns (uint8 newStage) 
    {
        uint256 ageInDays = (block.timestamp - plantedTimestamp) / 1 days;


        if (isTreeWithered(tokenId)) {
            newStage = 0;
        }

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

    function isTreeWithered(uint256 tokenId) internal view returns (bool) {
        TreeData storage tree = treeData[tokenId];

        if (tree.lastWateredTimestamp == 0) {
            return false;
        }
        return (tree.plantedTimestamp + 4 days < tree.lastWateredTimestamp);
    }

}
