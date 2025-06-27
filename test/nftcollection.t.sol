/*/ SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/TreeNFTCollection.sol";
import "../src/Whitelist.sol";

contract NFTCollectionTest is Test {
    TreeNFTCollection public nftCollection;
    Whitelist public whitelist;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public nonWhitelistedUser;

    uint256 public constant NFT_PRICE = 0.001 ether;
    uint256 public constant MAX_TOKENS = 5;

    event Withdraw(address indexed to, uint256 amount);
    event Mint(address indexed to, uint256 tokenId);
    event treeInitialized(uint256 tokenId, address indexed owner, uint256 timestamp);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        nonWhitelistedUser = makeAddr("nonWhitelistedUser");

        // Give users some ETH
        vm.deal(owner, 10 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);
        vm.deal(nonWhitelistedUser, 1 ether);

        // Deploy whitelist contract as owner
        vm.prank(owner);
        whitelist = new Whitelist(5);

        // Deploy NFT collection as owner
        vm.prank(owner);
        nftCollection = new TreeNFTCollection(address(whitelist));

        // Add users to whitelist
        vm.startPrank(owner);
        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);
        vm.stopPrank();
    }

    // Constructor Tests
    function testConstructor() public {
        assertEq(nftCollection.name(), "Tree Collection");
        assertEq(nftCollection.symbol(), "TREE");
        assertEq(nftCollection.owner(), owner);
        assertEq(nftCollection.reservedTokensClaimed(), 0);
    }

    function testConstructorRevertsWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Cannot be 0 address");
        new TreeNFTCollection(address(0));
    }

    function testSuccessfulMint() public {
        vm.prank(user1);
        vm.deal(user1, 3 ether);
        uint256 mintPrice = nftCollection.mint_price();

        // Expect events in the order they're emitted by the contract
        vm.expectEmit(true, true, false, true);
        emit treeInitialized(1, user1, block.timestamp);
        vm.expectEmit(true, true, false, true);
        emit Mint(user1, 1);
        console.log("balance of user1", user1.balance);
        console.log("nft price", nftCollection.mint_price());
        nftCollection.mint{value: mintPrice}(user1);

        assertEq(nftCollection.ownerOf(1), user1);
        assertEq(nftCollection.balanceOf(user1), 1);
        assertEq(nftCollection.reservedTokensClaimed(), 1);
        assertTrue(nftCollection.isMinted(user1));

        // Check tree data initialization
        (nftCollection.TreeType treeType, uint256 planted, uint256 watered, uint8 growth, uint16 waterCount) = nftCollection.getTreeData(1);
        assertEq(treeType, treeType.Snow);
        assertEq(planted, block.timestamp);
        assertEq(watered, block.timestamp);
        assertEq(growth, 0);
        assertEq(waterCount, 0);
    }

    function testMintRevertsWithZeroAddress() public {
        vm.prank(user1);
        vm.expectRevert("Invalid address");
        nftCollection.mint{value: NFT_PRICE}(address(0));
    }

    function testMintRevertsWithInsufficientFunds() public {
        vm.prank(user1);
        vm.expectRevert("Insufficient funds");
        nftCollection.mint{value: NFT_PRICE - 1}(user1, nftCollection.TreeType.summer);
    }

    function testMintRevertsWhenNotWhitelisted() public {
        vm.prank(nonWhitelistedUser);
        vm.expectRevert("not whitelisted");
        nftCollection.mint{value: NFT_PRICE}(nonWhitelistedUser);
    }

    function testMintRevertsWhenAlreadyMinted() public {
        // First mint
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        // Try to mint again
        vm.prank(user1);
        vm.expectRevert("Address already minted NFT");
        nftCollection.mint{value: NFT_PRICE}(user1);
    }

    function testMintRevertsWhenMaxTokensReached() public {
        // Mint all 5 tokens
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        vm.prank(user2);
        nftCollection.mint{value: NFT_PRICE}(user2);

        vm.prank(user3);
        nftCollection.mint{value: NFT_PRICE}(user3);

        // Add more users to whitelist for testing
        address user4 = makeAddr("user4");
        address user5 = makeAddr("user5");
        address user6 = makeAddr("user6");
        vm.deal(user4, 1 ether);
        vm.deal(user5, 1 ether);
        vm.deal(user6, 1 ether);

        vm.startPrank(owner);
        whitelist.addToWhitelist(user4);
        whitelist.addToWhitelist(user5);
        whitelist.addToWhitelist(user6);
        vm.stopPrank();

        vm.prank(user4);
        nftCollection.mint{value: NFT_PRICE}(user4);

        vm.prank(user5);
        nftCollection.mint{value: NFT_PRICE}(user5);

        // This should fail - all 5 tokens minted
        vm.prank(user6);
        vm.expectRevert("No more tokens left");
        nftCollection.mint{value: NFT_PRICE}(user6);
    }

    function testMintWithExcessPayment() public {
        uint256 excessPayment = NFT_PRICE * 2;
        vm.prank(user1);
        nftCollection.mint{value: excessPayment}(user1);

        assertEq(nftCollection.ownerOf(1), user1);
        assertEq(address(nftCollection).balance, excessPayment);
    }

    // Withdrawal Tests
    function testSuccessfulWithdraw() public {
        // First mint to add funds to contract
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        uint256 initialBalance = owner.balance;
        uint256 contractBalance = address(nftCollection).balance;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(owner, contractBalance);
        nftCollection.withdraw(contractBalance);

        assertEq(owner.balance, initialBalance + contractBalance);
        assertEq(address(nftCollection).balance, 0);
    }

    function testWithdrawRevertsWhenNotOwner() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        vm.prank(user1);
        vm.expectRevert();
        nftCollection.withdraw(NFT_PRICE);
    }

    function testWithdrawRevertsWithInsufficientBalance() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        vm.prank(owner);
        vm.expectRevert("Insufficient balance");
        nftCollection.withdraw(NFT_PRICE + 1);
    }

    function testPartialWithdraw() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        uint256 withdrawAmount = NFT_PRICE / 2;
        uint256 initialBalance = owner.balance;

        vm.prank(owner);
        nftCollection.withdraw(withdrawAmount);

        assertEq(owner.balance, initialBalance + withdrawAmount);
        assertEq(address(nftCollection).balance, NFT_PRICE - withdrawAmount);
    }

    // Tree Data Tests
    function testGetTreeDataAfterMint() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        (uint256 planted, uint256 watered, uint8 growth, uint16 waterCount) = nftCollection.getTreeData(1);

        assertEq(planted, block.timestamp);
        assertEq(watered, block.timestamp);
        assertEq(growth, 0);
        assertEq(waterCount, 0);
    }

    function testGetTreeDataRevertsForNonExistentToken() public {
        vm.expectRevert();
        nftCollection.getTreeData(1);
    }

    function testUpdateTreeData() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        uint16 newWateringCount = 5;
        uint8 newGrowthStage = 2;

        // Fast forward time
        vm.warp(block.timestamp + 1 days);


        (uint256 planted, uint256 watered, uint8 growth, uint16 waterCount) = nftCollection.getTreeData(1);

        assertEq(watered, block.timestamp); // Should be updated to current time
        assertEq(growth, newGrowthStage);
        assertEq(waterCount, newWateringCount);
        // Planted timestamp should remain unchanged
        assertEq(planted, block.timestamp - 1 days);
    }


    // Integration Tests
    function testMultipleMints() public {
        // Mint tokens for multiple users
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        vm.prank(user2);
        nftCollection.mint{value: NFT_PRICE}(user2);

        vm.prank(user3);
        nftCollection.mint{value: NFT_PRICE}(user3);

        assertEq(nftCollection.reservedTokensClaimed(), 3);
        assertEq(nftCollection.ownerOf(1), user1);
        assertEq(nftCollection.ownerOf(2), user2);
        assertEq(nftCollection.ownerOf(3), user3);

        assertTrue(nftCollection.isMinted(user1));
        assertTrue(nftCollection.isMinted(user2));
        assertTrue(nftCollection.isMinted(user3));

        assertEq(address(nftCollection).balance, NFT_PRICE * 3);
    }

    function testContractReceivesEther() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE * 2}(user1);

        assertEq(address(nftCollection).balance, NFT_PRICE * 2);
    }

    // Fuzz Tests
    function testFuzzMintPrice(uint256 payment) public {
        vm.assume(payment >= NFT_PRICE && payment <= 100 ether);

        vm.deal(user1, payment);
        vm.prank(user1);
        nftCollection.mint{value: payment}(user1);

        assertEq(nftCollection.ownerOf(1), user1);
        assertEq(address(nftCollection).balance, payment);
    }

    function testFuzzUpdateTreeData(uint16 wateringCount, uint8 growthStage) public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);


        (,, uint8 growth, uint16 waterCount) = nftCollection.getTreeData(1);
        assertEq(growth, growthStage);
        assertEq(waterCount, wateringCount);
    }

    // Edge Cases
    function testMintToSelfByNonOwner() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);

        assertEq(nftCollection.ownerOf(1), user1);
    }

    function testTokenIdSequence() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);
        assertEq(nftCollection.ownerOf(1), user1);

        vm.prank(user2);
        nftCollection.mint{value: NFT_PRICE}(user2);
        assertEq(nftCollection.ownerOf(2), user2);

        vm.prank(user3);
        nftCollection.mint{value: NFT_PRICE}(user3);
        assertEq(nftCollection.ownerOf(3), user3);
    }
}
*/