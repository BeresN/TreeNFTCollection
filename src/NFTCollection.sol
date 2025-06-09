// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Whitelist.sol";

contract NFTCollection is ERC721, ReentrancyGuard, Ownable {
    mapping(address => bool) public isMinted;
    uint256 public constant mint_price = 0.001 ether;
    uint256 public constant maxTokensId = 5;
    uint256 public reservedTokensClaimed = 0;
    Whitelist immutable whitelist;

    struct TreeData {
        uint256 plantedTimestamp;
        uint256 lastWateredTimestamp;
        uint8 growthStage;
        uint16 wateringCount;
    }

    mapping(uint256 => TreeData) public treeData;

    event Withdraw(address indexed to, uint256 amount);
    event Mint(address indexed to, uint256 tokenId);
    event treeInitialized(uint256 tokenId, address indexed owner, uint256 timestamp);

    constructor(address whitelistContract) ERC721("Tree Collection", "TREE") Ownable(msg.sender) {
        require(whitelistContract != address(0), "Cannot be 0 address");
        whitelist = Whitelist(whitelistContract);
    }

    function mint(address to) external payable nonReentrant {
        uint256 tokenId = reservedTokensClaimed + 1;
        require(whitelist.isWhitelisted(to), "not whitelisted");
        require(reservedTokensClaimed < maxTokensId, "No more tokens left");
        require(msg.value >= mint_price, "Insufficient funds");

        if (isMinted[to]) revert("Address already minted NFT");

        reservedTokensClaimed++;
        isMinted[to] = true;

        treeData[tokenId] = TreeData({
            plantedTimestamp: block.timestamp,
            lastWateredTimestamp: block.timestamp,
            growthStage: 0,
            wateringCount: 0
        });

        _safeMint(to, tokenId);
        emit treeInitialized(tokenId, ownerOf(tokenId), block.timestamp);
        emit Mint(to, tokenId);
    }

    function withdraw(uint256 amount) external nonReentrant onlyOwner {
        require(msg.sender != address(0), "cannot be address 0");
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function getTreeData(uint256 tokenId)
        external
        view
        returns (uint256 plantedTimestamp, uint256 lastWateredTimestamp, uint8 growthStage, uint16 wateringCount)
    {
        require(ownerOf(tokenId) != address(0), "token not minted yet");
        TreeData storage tree = treeData[tokenId];
        return (tree.plantedTimestamp, tree.lastWateredTimestamp, tree.growthStage, tree.wateringCount);
    }

    function updateTreeData(uint256 tokenId, uint16 _newWateringCount, uint8 _newGrowthStage) external {
        require(ownerOf(tokenId) != address(0), "token not minted yet");
        TreeData storage tree = treeData[tokenId];
        tree.lastWateredTimestamp = block.timestamp;
        tree.wateringCount = _newWateringCount;
        tree.growthStage = _newGrowthStage;
    }
}
