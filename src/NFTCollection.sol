// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Whitelist.sol";

contract NFTCollection is ERC721, ReentrancyGuard{
    mapping(address => bool) public isMinted;
    uint256 public constant NFT_PRICE = 0.001 ether;
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


    constructor(
        address whitelistContract
    ) ERC721("Tree Collection", "TREE"){
        require(whitelistContract != address(0), "Cannot be 0 address");
        whitelist = Whitelist(whitelistContract);
    }
    function mint(address to) external payable nonReentrant{
        uint256 tokenId = reservedTokensClaimed + 1;
        require(to != address(0), "Invalid address");
        require(reservedTokensClaimed < maxTokensId, "No more tokens left");
        require(msg.value >= NFT_PRICE, "Insufficient funds");
        require(whitelist.isWhitelisted(to), "not whitelisted");
        if(isMinted[to]) revert("Address already minted NFT");

        reservedTokensClaimed++;
        isMinted[to] = true;
        initializeTree(tokenId);  
        emit Mint(to, tokenId);
        _safeMint(to, tokenId);
    }

    function initializeTree(uint256 tokenId) internal{
        treeData[tokenId] = TreeData({
            plantedTimestamp: block.timestamp,
            lastWateredTimestamp: block.timestamp,
            growthStage: 0, 
            wateringCount: 0
        });
        emit treeInitialized(tokenId, ownerOf(tokenId), block.timestamp);
    }


    function withdraw(uint256 amount) external nonReentrant{
        require(amount <= address(this).balance, "Insufficient balance");
        require(whitelist.isWhitelisted(msg.sender), "not whitelisted");
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }
}
