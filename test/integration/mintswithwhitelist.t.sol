// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../../src/TreeNFTCollection.sol";
import "../../src/Whitelist.sol";

contract NFTCollectionTest is Test {
    TreeNFTCollection public nftCollection;
    Whitelist public whitelist;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    address public nonWhitelistedUser;

    uint256 public constant NFT_PRICE = 0.001 ether;
    uint256 public constant MAX_TOKENS = 3;

    event Withdraw(address indexed to, uint256 amount);
    event Mint(address indexed to, uint256 tokenId);
    event treeInitialized(uint256 tokenId, address indexed owner, uint256 timestamp);


    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");


           // Give users some ETH
        vm.deal(owner, 10 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);
        vm.deal(user4, 1 ether);

        vm.deal(nonWhitelistedUser, 1 ether);

        // Deploy whitelist contract as owner
        vm.prank(owner);
        whitelist = new Whitelist(5);

        // Deploy NFT collection as owner
        vm.prank(owner);
        nftCollection = new TreeNFTCollection(address(whitelist));
 
        TreeNFTCollection.TreeType summerType = TreeNFTCollection.TreeType.Summer;
        TreeNFTCollection.TreeType autumnType = TreeNFTCollection.TreeType.Autumn;
        TreeNFTCollection.TreeType snowType = TreeNFTCollection.TreeType.Snow;



        // Add users to whitelist
        vm.startPrank(owner);
        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);
        whitelist.addToWhitelist(user4);

        vm.stopPrank();
    }

    function testMultipleMints() public {
        // Mint tokens for multiple users

        TreeNFTCollection.TreeType summerType = TreeNFTCollection.TreeType.Summer;
        TreeNFTCollection.TreeType autumnType = TreeNFTCollection.TreeType.Autumn;
        TreeNFTCollection.TreeType snowType = TreeNFTCollection.TreeType.Snow;

        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1, summerType);

        vm.prank(user2);
        nftCollection.mint{value: NFT_PRICE}(user2, autumnType);

        vm.prank(user3);
        nftCollection.mint{value: NFT_PRICE}(user3, snowType);

        assertEq(nftCollection.reservedTokensClaimed(), 3);
        assertEq(nftCollection.ownerOf(1), user1);
        assertEq(nftCollection.ownerOf(2), user2);
        assertEq(nftCollection.ownerOf(3), user3);

        assertTrue(nftCollection.isMinted(user1));
        assertTrue(nftCollection.isMinted(user2));
        assertTrue(nftCollection.isMinted(user3));

        assertEq(address(nftCollection).balance, NFT_PRICE * 3);
    }

}