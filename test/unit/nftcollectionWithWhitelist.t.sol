// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
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
    string constant EXPECTED_BASE_URI = "https://white-binding-zebra-376.mypinata.cloud/ipfs/bafybeiacg6slhqk2rn65o4vqh2idzap27lhw2jq3jde3juol3nujtjyffe";

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

     function testConstructor() public {
        assertEq(nftCollection.name(), "Tree Collection");
        assertEq(nftCollection.symbol(), "TREE");
        assertEq(nftCollection.owner(), owner);
        assertEq(nftCollection.reservedTokensClaimed(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                               MINT TEST
    //////////////////////////////////////////////////////////////*/

      function testSuccessfulMint() public {
        uint256 mintPrice = nftCollection.mint_price();

        TreeNFTCollection.TreeType snowType = TreeNFTCollection.TreeType.Snow;

        // Expect events in the order they're emitted by the contract
        vm.expectEmit(true, true, false, true);
        emit treeInitialized(1, user1, block.timestamp);
        vm.expectEmit(true, true, false, true);
        emit Mint(user1, 1);
        console.log("balance of user1", user1.balance);
        console.log("nft price", nftCollection.mint_price());
        vm.prank(user1);
        nftCollection.mint{value: mintPrice}(user1, snowType);

        assertEq(nftCollection.ownerOf(1), user1);
        assertEq(nftCollection.balanceOf(user1), 1);
        assertEq(nftCollection.reservedTokensClaimed(), 1);
        assertTrue(nftCollection.isMinted(user1));

        // Check tree data initialization
        (TreeNFTCollection.TreeType treeType, uint256 planted, uint256 watered, uint8 growth, uint16 waterCount) = nftCollection.getTreeData(1);
        assertEq(uint8(treeType), 1);
        assertEq(planted, block.timestamp);
        assertEq(watered, 0);
        assertEq(growth, 1);
        assertEq(waterCount, 0);
    }

    function testMintRevertsWithInsufficientFunds() public {
        TreeNFTCollection.TreeType summerType = TreeNFTCollection.TreeType.Summer;

        vm.prank(user1);
        vm.expectRevert("Insufficient funds");
        nftCollection.mint{value: NFT_PRICE - 1}(user1, summerType);
    }

    function testMintRevertsWhenNotWhitelisted() public {
        vm.prank(nonWhitelistedUser);
        TreeNFTCollection.TreeType snowType = TreeNFTCollection.TreeType.Snow;

        vm.expectRevert("not whitelisted");
        nftCollection.mint{value: NFT_PRICE}(nonWhitelistedUser, snowType);
    }

    function testMintRevertsWhenAlreadyMinted() public {
        // First mint
        vm.prank(user1);
        TreeNFTCollection.TreeType snowType = TreeNFTCollection.TreeType.Snow;

        nftCollection.mint{value: NFT_PRICE}(user1, snowType);

        // Try to mint again
        vm.prank(user1);
        vm.expectRevert("Address already minted NFT");
        nftCollection.mint{value: NFT_PRICE}(user1, snowType);
    }

       function testMintRevertsWhenMaxTokensReached() public {
        // Mint all 5 tokens
        TreeNFTCollection.TreeType snowType = TreeNFTCollection.TreeType.Snow;

        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1, snowType);

        vm.prank(user2);
        nftCollection.mint{value: NFT_PRICE}(user2, snowType);

        vm.prank(user3);
        nftCollection.mint{value: NFT_PRICE}(user3, snowType);

        vm.expectRevert("No more tokens left");
        nftCollection.mint{value: NFT_PRICE}(user4, snowType);
    }

      /*//////////////////////////////////////////////////////////////
                             WITHDRAW TEST
      //////////////////////////////////////////////////////////////*/

    function testSuccessfulWithdraw() public {
        // First mint to add funds to contract

        TreeNFTCollection.TreeType autumnType = TreeNFTCollection.TreeType.Autumn;

        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1, autumnType);

        uint256 initialBalance = owner.balance;
        uint256 contractBalance = address(nftCollection).balance;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(owner, contractBalance);
        nftCollection.withdraw(contractBalance);

        assertEq(owner.balance, initialBalance + contractBalance);
        assertEq(address(nftCollection).balance, 0);
    }

    function testWithdrawRevertsWithInsufficientBalance() public {
        TreeNFTCollection.TreeType autumnType = TreeNFTCollection.TreeType.Autumn;

        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1, autumnType);

        vm.prank(owner);
        vm.expectRevert("Insufficient balance");
        nftCollection.withdraw(NFT_PRICE + 1);
    }

    function testPartialWithdraw() public {
        TreeNFTCollection.TreeType autumnType = TreeNFTCollection.TreeType.Autumn;

        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1, autumnType);

        uint256 withdrawAmount = NFT_PRICE / 2;
        uint256 initialBalance = owner.balance;

        vm.prank(owner);
        nftCollection.withdraw(withdrawAmount);

        assertEq(owner.balance, initialBalance + withdrawAmount);
        assertEq(address(nftCollection).balance, NFT_PRICE - withdrawAmount);
    }


     function testWithdrawRevertsWhenNotOwner() public {
        TreeNFTCollection.TreeType autumnType = TreeNFTCollection.TreeType.Autumn;

        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1, autumnType);

        vm.prank(user1);
        vm.expectRevert();
        nftCollection.withdraw(NFT_PRICE);
    }

    /*//////////////////////////////////////////////////////////////
                             GET TREE DATA
    //////////////////////////////////////////////////////////////*/


      function testGetTreeDataRevertsForNonExistentToken() public {
        vm.expectRevert();
        nftCollection.getTreeData(1);
    }

    /*//////////////////////////////////////////////////////////////
                               URI TESTS
    //////////////////////////////////////////////////////////////*/

     function testURI() public {
   
        TreeNFTCollection.TreeType autumnType = TreeNFTCollection.TreeType.Autumn;
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1, autumnType);

        string memory baseURI = nftCollection.baseURI();
         console.log("Base URI from getter:", baseURI);

        string memory tokenURI1 = nftCollection.tokenURI(1);
        string memory expectedURI1 = "https://white-binding-zebra-376.mypinata.cloud/ipfs/bafybeihmyjwqmwilyu6g7bcu76rkoimr7pm6rgsmnryy3yndf4iyjjxbcq/1.json";
        
        console.log("Token URI for token 1:", tokenURI1);
        console.log("Expected URI:", expectedURI1);
        
        assertEq(tokenURI1, expectedURI1, "Token URI should match expected format");

    }
    
    function testTokenURIMultipleTokens() public {
        // Mint another token
        TreeNFTCollection.TreeType snowType = TreeNFTCollection.TreeType.Snow;
        TreeNFTCollection.TreeType autumnType = TreeNFTCollection.TreeType.Autumn;
        TreeNFTCollection.TreeType summerType = TreeNFTCollection.TreeType.Summer;



        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1, autumnType);  

        vm.prank(user2);
        nftCollection.mint{value: NFT_PRICE}(user2, snowType);

         vm.prank(user3);
        nftCollection.mint{value: NFT_PRICE}(user3, summerType);
        
        // Test both tokens
        string memory tokenURI1 = nftCollection.tokenURI(1);
        string memory tokenURI2 = nftCollection.tokenURI(2);
        string memory tokenURI3 = nftCollection.tokenURI(3);

        string memory expectedURI1 = "https://white-binding-zebra-376.mypinata.cloud/ipfs/bafybeihmyjwqmwilyu6g7bcu76rkoimr7pm6rgsmnryy3yndf4iyjjxbcq/9.json";
        string memory expectedURI2 = "https://white-binding-zebra-376.mypinata.cloud/ipfs/bafybeihmyjwqmwilyu6g7bcu76rkoimr7pm6rgsmnryy3yndf4iyjjxbcq/5.json";
        string memory expectedURI3 = "https://white-binding-zebra-376.mypinata.cloud/ipfs/bafybeihmyjwqmwilyu6g7bcu76rkoimr7pm6rgsmnryy3yndf4iyjjxbcq/1.json";

        assertEq(tokenURI1, expectedURI1, "Token 1 URI should be correct");
        assertEq(tokenURI2, expectedURI2, "Token 2 URI should be correct");
        assertEq(tokenURI3, expectedURI3, "Token 3 URI should be correct");
        console.log("Token 1 URI:", tokenURI1);
        console.log("Token 2 URI:", tokenURI2);
        console.log("Token 3 URI:", tokenURI3);
    }
    

}