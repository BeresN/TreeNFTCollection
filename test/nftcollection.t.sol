// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/NFTCollection.sol";
import "../src/Whitelist.sol";

contract NFTCollectionTest is Test {
    NFTCollection public nftCollection;
    Whitelist public whitelist;
    
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public nonWhitelisted = makeAddr("nonWhitelisted");
    
    uint256 public constant NFT_PRICE = 0.001 ether;
    uint256 public constant MAX_TOKENS = 5;
    uint256 public constant MAX_WHITELIST = 10;

    event Withdraw(address indexed to, uint256 amount);
    event Mint(address indexed to, uint256 tokenId);
    event treeInitialized(uint256 tokenId, address indexed owner, uint256 timestamp);

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy whitelist contract
        whitelist = new Whitelist(owner, MAX_WHITELIST);
        
        // Deploy NFT collection
        nftCollection = new NFTCollection(address(whitelist));
        
        // Add users to whitelist
        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);
        whitelist.addToWhitelist(owner);
        
        vm.stopPrank();
        
        // Give users some ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(nonWhitelisted, 10 ether);
        vm.deal(owner, 10 ether);
    }

    // ============ Constructor Tests ============
    
    function test_Constructor_Success() public view {
        assertEq(nftCollection.name(), "Tree Collection");
        assertEq(nftCollection.symbol(), "TREE");
        assertEq(nftCollection.reservedTokensClaimed(), 0);
    }
    
    function test_Constructor_RevertZeroAddress() public {
        vm.expectRevert("Cannot be 0 address");
        new NFTCollection(address(0));
    }

    // ============ Mint Function Tests ============
    
    function test_Mint_Success() public {
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true); // owner is topic1, tokenId & timestamp are data
        emit treeInitialized(1, user1, block.timestamp); // block.timestamp in test should match contract if no other ops

        vm.expectEmit(true, false, false, true); // to is topic1, tokenId is data
        emit Mint(user1, 1);
        
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        // Verify state changes
        assertEq(nftCollection.ownerOf(1), user1);
        assertEq(nftCollection.reservedTokensClaimed(), 1);
        assertTrue(nftCollection.isMinted(user1));
        assertEq(nftCollection.balanceOf(user1), 1);
        
        // Verify tree data
        (
            uint256 plantedTimestamp,
            uint256 lastWateredTimestamp,
            uint8 growthStage,
            uint16 wateringCount
        ) = nftCollection.treeData(1);
        
        assertEq(plantedTimestamp, block.timestamp);
        assertEq(lastWateredTimestamp, block.timestamp);
        assertEq(growthStage, 0);
        assertEq(wateringCount, 0);
        
        vm.stopPrank();
    }
    
    function test_Mint_RevertInvalidAddress() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid address");
        nftCollection.mint{value: NFT_PRICE}(address(0));
        vm.stopPrank();
    }
    
    function test_Mint_RevertInsufficientFunds() public {
        vm.startPrank(user1);
        vm.expectRevert("Insufficient funds");
        nftCollection.mint{value: NFT_PRICE - 1}(user1);
        vm.stopPrank();
    }
    
    function test_Mint_RevertNotWhitelisted() public {
        vm.startPrank(nonWhitelisted);
        vm.expectRevert("not whitelisted");
        nftCollection.mint{value: NFT_PRICE}(nonWhitelisted);
        vm.stopPrank();
    }
    
    function test_Mint_RevertAlreadyMinted() public {
        vm.startPrank(user1);
        
        // First mint should succeed
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        // Second mint should fail
        vm.expectRevert("Address already minted NFT");
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        vm.stopPrank();
    }
    
    function test_Mint_RevertMaxTokensReached() public {
        // Mint all 5 tokens
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        vm.prank(user2);
        nftCollection.mint{value: NFT_PRICE}(user2);
        
        vm.prank(user3);
        nftCollection.mint{value: NFT_PRICE}(user3);
        
        // Add more users to whitelist for testing
        vm.startPrank(owner);
        address user4 = makeAddr("user4");
        address user5 = makeAddr("user5");
        address user6 = makeAddr("user6");
        
        whitelist.addToWhitelist(user4);
        whitelist.addToWhitelist(user5);
        whitelist.addToWhitelist(user6);
        vm.stopPrank();
        
        vm.deal(user4, 1 ether);
        vm.deal(user5, 1 ether);
        vm.deal(user6, 1 ether);
        
        vm.prank(user4);
        nftCollection.mint{value: NFT_PRICE}(user4);
        
        vm.prank(user5);
        nftCollection.mint{value: NFT_PRICE}(user5);
        
        // 6th mint should fail
        vm.prank(user6);
        vm.expectRevert("No more tokens left");
        nftCollection.mint{value: NFT_PRICE}(user6);
    }
    
    function test_Mint_ExcessPayment() public {
        vm.startPrank(user1);
        
        uint256 excessPayment = NFT_PRICE * 2;
        uint256 balanceBefore = user1.balance;
        
        nftCollection.mint{value: excessPayment}(user1);
        
        // User should still own the NFT
        assertEq(nftCollection.ownerOf(1), user1);
        
        // Contract should receive the full payment
        assertEq(address(nftCollection).balance, excessPayment);
        assertEq(user1.balance, balanceBefore - excessPayment);
        
        vm.stopPrank();
    }

    // ============ Withdraw Function Tests ============
    
    function test_Withdraw_Success() public {
        // First, mint some NFTs to add funds to contract
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        vm.prank(user2);
        nftCollection.mint{value: NFT_PRICE}(user2);
        
        uint256 contractBalance = address(nftCollection).balance;
        assertEq(contractBalance, NFT_PRICE * 2);
        
        // Test withdrawal
        vm.startPrank(user1);
        uint256 withdrawAmount = NFT_PRICE;
        uint256 balanceBefore = user1.balance;
        
        vm.expectEmit(true, false, false, true);
        emit Withdraw(user1, withdrawAmount);
        
        nftCollection.withdraw(withdrawAmount);
        
        assertEq(user1.balance, balanceBefore + withdrawAmount);
        assertEq(address(nftCollection).balance, contractBalance - withdrawAmount);
        
        vm.stopPrank();
    }
    
    function test_Withdraw_RevertNotWhitelisted() public {
        // Add funds to contract
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        vm.startPrank(nonWhitelisted);
        vm.expectRevert("not whitelisted");
        nftCollection.withdraw(NFT_PRICE);
        vm.stopPrank();
    }
    
    function test_Withdraw_RevertInsufficientBalance() public {
        vm.startPrank(user1);
        vm.expectRevert("Insufficient balance");
        nftCollection.withdraw(1 ether);
        vm.stopPrank();
    }
    
    function test_Withdraw_RevertTransferFailed() public {
        // Create a contract that cannot receive ETH
        RejectEther rejectContract = new RejectEther();
        
        // Add the contract to whitelist
        vm.prank(owner);
        whitelist.addToWhitelist(address(rejectContract));
        
        // Add funds to NFT contract
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        // Try to withdraw to the reject contract
        vm.prank(address(rejectContract));
        vm.expectRevert("Transfer failed");
        nftCollection.withdraw(NFT_PRICE);
    }

    // ============ View Function Tests ============
    
    function test_TreeData_InitializedCorrectly() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        (
            uint256 plantedTimestamp,
            uint256 lastWateredTimestamp,
            uint8 growthStage,
            uint16 wateringCount
        ) = nftCollection.treeData(1);
        
        assertEq(plantedTimestamp, block.timestamp);
        assertEq(lastWateredTimestamp, block.timestamp);
        assertEq(growthStage, 0);
        assertEq(wateringCount, 0);
    }
    
    function test_Constants() public view {
        assertEq(nftCollection.NFT_PRICE(), 0.001 ether);
        assertEq(nftCollection.maxTokensId(), 5);
    }

    // ============ Integration Tests ============
    
    function test_MintMultipleUsers() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            nftCollection.mint{value: NFT_PRICE}(users[i]);
            
            assertEq(nftCollection.ownerOf(i + 1), users[i]);
            assertTrue(nftCollection.isMinted(users[i]));
        }
        
        assertEq(nftCollection.reservedTokensClaimed(), 3);
        assertEq(address(nftCollection).balance, NFT_PRICE * 3);
    }
    
    function test_MintAndWithdraw() public {
        // Mint NFT
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        // Withdraw funds
        vm.prank(user1);
        nftCollection.withdraw(NFT_PRICE);
        
        // Verify final state
        assertEq(nftCollection.ownerOf(1), user1);
        assertEq(address(nftCollection).balance, 0);
    }

    // ============ Fuzz Tests ============
    
    function testFuzz_Mint_ValidPayment(uint256 payment) public {
    // Manual setup for this fuzz test
    vm.startPrank(owner);
    whitelist = new Whitelist(owner, MAX_WHITELIST);
    nftCollection = new NFTCollection(address(whitelist));
    whitelist.addToWhitelist(user1);
    vm.stopPrank();
    vm.deal(user1, 150 ether); // Ensure user1 has enough for any payment

    // Fuzz logic
    vm.assume(payment >= NFT_PRICE && payment <= 100 ether);

    vm.prank(user1);
    nftCollection.mint{value: payment}(user1);

    assertEq(nftCollection.ownerOf(1), user1);
    assertEq(address(nftCollection).balance, payment);
    }
    
    function testFuzz_Withdraw_ValidAmount(uint256 amount) public {
        // Setup: mint to add funds
        vm.prank(user1);
        nftCollection.mint{value: 1 ether}(user1);
        
        vm.assume(amount <= address(nftCollection).balance);
        
        vm.prank(user1);
        nftCollection.withdraw(amount);
        
        assertEq(address(nftCollection).balance, 1 ether - amount);
    }

    // ============ Edge Cases ============
    
    function test_Mint_ExactPrice() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        assertEq(nftCollection.ownerOf(1), user1);
    }
    
    function test_Withdraw_ZeroAmount() public {
        vm.prank(user1);
        nftCollection.mint{value: NFT_PRICE}(user1);
        
        vm.prank(user1);
        nftCollection.withdraw(0);
        
        // Should succeed but not change balances
        assertEq(address(nftCollection).balance, NFT_PRICE);
    }
    
    function test_Mint_TokenIdSequence() public {
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

// Helper contract for testing transfer failures
contract RejectEther {
    // This contract cannot receive ETH
    receive() external payable {
        revert("Cannot receive ETH");
    }
}
