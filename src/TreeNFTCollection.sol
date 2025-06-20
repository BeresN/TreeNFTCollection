// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Whitelist.sol";

contract TreeNFTCollection is ERC721, ReentrancyGuard, Ownable {

    enum TreeType{ Normal, Snow }
    mapping(address => bool) public isMinted;
    uint256 public constant mint_price = 0.001 ether;
    uint8 public constant maxTokensId = 2;
    uint8 public reservedTokensClaimed = 0;
    Whitelist immutable whitelist;
    string public baseURI;

    struct TreeData {
        TreeType treeType;
        uint256 plantedTimestamp;
        uint256 lastWateredTimestamp;
        uint8 growthStage;
        uint16 wateringCount;
    }

    mapping(uint256 => TreeData) public treeData;

    event Withdraw(address indexed to, uint256 amount);
    event Mint(address indexed to, uint256 tokenId);
    event treeInitialized(
        uint256 tokenId,
        address indexed owner,
        uint256 timestamp
    );

    constructor(
        address whitelistContract
    ) ERC721("Tree Collection", "TREE") Ownable(msg.sender) {
        require(whitelistContract != address(0), "Cannot be 0 address");
        whitelist = Whitelist(whitelistContract);
    }

    function mint(address to, TreeType treeType) external payable nonReentrant {
        require(whitelist.isWhitelisted(to), "not whitelisted");
        require(treeType == TreeType.Normal || treeType == TreeType.Snow, "Invalid initial type");
        require(reservedTokensClaimed < maxTokensId, "No more tokens left");
        require(msg.value >= mint_price, "Insufficient funds");
        if (isMinted[to]) revert("Address already minted NFT");
        uint256 tokenId = reservedTokensClaimed + 1;
        reservedTokensClaimed++;
        isMinted[to] = true;

        treeData[tokenId] = TreeData({
            treeType: treeType,
            plantedTimestamp: block.timestamp,
            lastWateredTimestamp: 0,
            growthStage: 1,
            wateringCount: 0
        });

        _safeMint(to, tokenId);
        emit treeInitialized(tokenId, ownerOf(tokenId), block.timestamp);
        emit Mint(to, tokenId);
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(msg.sender != address(0), "cannot be address 0");
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function getTreeData(
        uint256 tokenId
    )
        external
        view
        returns (
            uint256 plantedTimestamp,
            uint256 lastWateredTimestamp,
            uint8 growthStage,
            uint16 wateringCount
        )
    {
        require(ownerOf(tokenId) != address(0), "token not minted yet");
        TreeData storage tree = treeData[tokenId];
        return (
            tree.plantedTimestamp,
            tree.lastWateredTimestamp,
            tree.growthStage,
            tree.wateringCount
        );
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            ownerOf(tokenId) != address(0),
            "Uri query for non-existent token"
        );
        return
            string(
                abi.encodePacked(
                    baseURI,
                    "/",
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    function setBaseUri(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }
}
