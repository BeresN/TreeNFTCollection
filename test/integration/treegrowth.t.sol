// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";

import {console} from "forge-std/console.sol";

import "../../src/CalculateStage.sol";
import "../../src/TreeNFTCollection.sol";
import "../../src/Whitelist.sol";

contract TreeGrowthStagesTest is Test {
    TreeGrowthStages public treeGrowth;
    Whitelist public whitelist;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public nonOwner;

    uint256 public constant WATERING_COST = 0.0004 ether;
    uint256 public constant REVIVAL_COST = WATERING_COST * 5;
    uint256 public constant WATERING_COOLDOWN = 1 days;
    uint256 public constant NFT_PRICE = 0.001 ether;

    event treeGrowthCalculation(
        uint256 tokenId,
        uint8 growthStage,
        uint16 wateringCount
    );

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        nonOwner = makeAddr("nonOwner");

        // Give users some ETH
        vm.deal(owner, 10 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);
        vm.deal(nonOwner, 1 ether);

        // Deploy whitelist contract
        vm.prank(owner);
        whitelist = new Whitelist(5);

        // Deploy TreeGrowthStages contract (which inherits from NFTCollection)
        vm.prank(owner);
        treeGrowth = new TreeGrowthStages(address(whitelist));

        // Add users to whitelist
        vm.startPrank(owner);
        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);
        vm.stopPrank();

        // Mint NFTs for testing - Fixed enum syntax
        vm.prank(user1);
        treeGrowth.mint{value: NFT_PRICE}(
            user1,
            TreeNFTCollection.TreeType.Summer
        );

        vm.prank(user2);
        treeGrowth.mint{value: NFT_PRICE}(
            user2,
            TreeNFTCollection.TreeType.Snow
        );

        vm.prank(user3);
        treeGrowth.mint{value: NFT_PRICE}(
            user3,
            TreeNFTCollection.TreeType.Autumn
        );
    }

    // Constructor and Basic Tests
    function testInheritance() public {
        // Verify the contract properly inherits NFTCollection functionality
        assertEq(treeGrowth.ownerOf(1), user1);  // Summer tree
        assertEq(treeGrowth.ownerOf(5), user2);  // Snow tree  
        assertEq(treeGrowth.ownerOf(9), user3);  // Autumn tree
        assertEq(treeGrowth.balanceOf(user1), 1);
        assertEq(treeGrowth.balanceOf(user2), 1);
    }

    // Watering Tests
    function testWateringTreeBasic() public {
        uint256 wateringCost = treeGrowth.wateringCost();

        vm.prank(user1);
        emit treeGrowthCalculation(1, 1, 1); // Include plantedTimestamp
        treeGrowth.wateringTree{value: wateringCost}(1);

        // Verify tree data updated
        (, , uint256 lastWatered, uint8 stage, uint16 count) = treeGrowth
            .getTreeData(1);
        assertEq(lastWatered, block.timestamp);
        assertEq(stage, 1);
        assertEq(count, 1);
    }

    function testWateringTreeRevertsInsufficientPayment() public {
        uint256 wateringCost = treeGrowth.wateringCost();
        vm.prank(user1);
        vm.expectRevert("insufficient payment");
        treeGrowth.wateringTree{value: wateringCost - 1}(1);
    }

    function testWateringTreeRevertsNotOwner() public {
        uint256 wateringCost = treeGrowth.wateringCost();
        vm.prank(user2);
        vm.expectRevert("only owner can water the tree");
        treeGrowth.wateringTree{value: wateringCost}(1); // user2 trying to water user1's tree
    }

    function testWateringTreeRevertsCooldown() public {
        // First watering
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        // Try to water again immediately
        vm.prank(user1);
        vm.expectRevert("tree was already watered");
        treeGrowth.wateringTree{value: WATERING_COST}(1);
    }

    function testWateringAfterCooldown() public {
        // First watering
        uint256 Cooldown = 1 days;
        uint256 wateringCost = treeGrowth.wateringCost();
        (
            TreeNFTCollection.TreeType treeType,
            uint256 plantedTimestamp,
            uint256 lastWateredTimestamp,
            uint8 growthStage,
            uint16 count
        ) = treeGrowth.getTreeData(1);
        assertEq(uint256(treeType), 0); // Normal = 0
        assertTrue(plantedTimestamp > 0); // Should be set to block.timestamp
        assertEq(lastWateredTimestamp, 0);
        assertEq(growthStage, 1); // Initial stage is 1
        assertEq(count, 0);

        vm.prank(user1);
        treeGrowth.wateringTree{value: wateringCost}(1);

        // Fast forward past cooldown
        vm.warp(block.timestamp + Cooldown);

        // Second watering should work
        vm.prank(user1);
        treeGrowth.wateringTree{value: wateringCost}(1);

        (, , , , count) = treeGrowth.getTreeData(1);
        assertEq(count, 2);
    }

    // Growth Stage Calculation Tests
    function testGrowthStagesSeedling() public {
        // New tree should be stage 1 (sapling)
        vm.startPrank(user1);

        (, , , uint8 stage, ) = treeGrowth.getTreeData(1);
        assertEq(stage, 1); // Initial stage is 1

        // Water a few times but not enough to advance
        for (uint256 i = 0; i < 4; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }
        vm.stopPrank();

        (, , , stage, ) = treeGrowth.getTreeData(1);
        assertEq(stage, 1); // Still sapling
    }

    function testGrowthStagesYoungTree() public {
        vm.startPrank(user1);

        // Fast forward 1 month
        vm.warp(block.timestamp + 30 days);

        // Water 15 times to reach young tree stage
        for (uint256 i = 0; i < 15; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            if (i < 14) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        vm.stopPrank();

        (, , , uint8 stage, uint16 count) = treeGrowth.getTreeData(1);
        assertEq(stage, 2); // Young tree
        assertEq(count, 15);
    }

    function testGrowthStagesMatureTree() public {
        vm.startPrank(user1);

        // Fast forward 2 months
        vm.warp(block.timestamp + 60 days);

        // Water 30 times to reach mature tree stage
        for (uint256 i = 0; i < 30; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            if (i < 29) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        vm.stopPrank();

        (, , , uint8 stage, uint16 count) = treeGrowth.getTreeData(1);
        assertEq(stage, 3); // Mature tree
        assertEq(count, 30);
    }

    function testGrowthStagesAncientTree() public {
        vm.startPrank(user1);

        // Fast forward 4 months
        vm.warp(block.timestamp + 120 days);

        // Water 50 times to reach ancient tree stage
        for (uint256 i = 0; i < 50; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            if (i < 49) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        vm.stopPrank();

        (, , , uint8 stage, uint16 count) = treeGrowth.getTreeData(1);
        assertEq(stage, 4); // Ancient tree
        assertEq(count, 50);
    }

    // Edge Cases for Growth Stages
    function testGrowthStageRequiresBothAgeAndWatering() public {
        vm.startPrank(user1);

        // Test young tree requirements: 30+ days AND 15+ waterings

        // Only age, no watering
        vm.warp(block.timestamp + 35 days);
        treeGrowth.wateringTree{value: WATERING_COST}(1);
        (, , , uint8 stage, ) = treeGrowth.getTreeData(1);
        assertEq(stage, 1); // Still sapling (only 1 watering)

        vm.stopPrank();

        // Mint new tree for clean test
        address user3 = makeAddr("user3");
        vm.deal(user3, 1 ether);
        vm.prank(owner);
        whitelist.addToWhitelist(user3);
        vm.prank(user3);
        treeGrowth.mint{value: NFT_PRICE}(
            user3,
            TreeNFTCollection.TreeType.Summer
        );

        vm.startPrank(user3);
        // Water 15 times but no time passed
        for (uint256 i = 0; i < 15; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(9);
            if (i < 14) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        (, , , stage, ) = treeGrowth.getTreeData(9);
        assertEq(stage, 1); // Still sapling (not enough age)

        vm.stopPrank();
    }

    // Payment and Ether Handling Tests
    function testWateringWithExactPayment() public {
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        // Contract should receive the payment
        assertEq(address(treeGrowth).balance, NFT_PRICE * 2 + WATERING_COST); // 2 mints + 1 watering
    }

    function testWateringAcceptsExcessPayment() public {
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST * 2}(1);

        // Should work with excess payment
        (, , , , uint16 count) = treeGrowth.getTreeData(1);
        assertEq(count, 1);
    }

    // Integration Tests
    function testMultipleUsersWateringTrees() public {
        // User1 waters their tree
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        // User2 waters their tree
        vm.prank(user2);
        treeGrowth.wateringTree{value: WATERING_COST}(5);

        // Check both trees were updated independently
        (, , , , uint16 count1) = treeGrowth.getTreeData(1);
        (, , , , uint16 count2) = treeGrowth.getTreeData(5);

        assertEq(count1, 1);
        assertEq(count2, 1);
    }

    // Fuzz Tests
    function testFuzzWateringAmount(uint256 payment) public {
        vm.assume(payment >= WATERING_COST && payment <= 1 ether);

        vm.deal(user1, payment);
        vm.prank(user1);
        treeGrowth.wateringTree{value: payment}(1);

        (, , , , uint16 count) = treeGrowth.getTreeData(1);
        assertEq(count, 1);
    }

    // Test nonexistent token
    function testWateringNonexistentToken() public {
        vm.prank(user1);
        vm.expectRevert();
        treeGrowth.wateringTree{value: WATERING_COST}(999);
    }

    // Test event emission
    function testTreeGrowthCalculationEvent() public {
        // Fast forward and water to reach young tree
        vm.warp(block.timestamp + 30 days);

        // The 15th watering should emit stage 2
        for (uint256 i = 0; i < 14; i++) {
            vm.prank(user1);
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }
        // 15th watering should trigger young tree stage
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);
        (, , , uint8 currentStage, ) = treeGrowth.getTreeData(1);

        assertEq(currentStage, 2, "should be young tree");
    }

    function testWitheredTreeHandle() public {
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        (
            TreeNFTCollection.TreeType treeType,
            ,
            uint256 lastWatered,
            ,

        ) = treeGrowth.getTreeData(1);
        vm.warp(lastWatered + 6 days);

        vm.prank(user1);
        vm.expectRevert("Tree is withered, revive first");
        treeGrowth.wateringTree{value: WATERING_COST}(1);
    }

    function testReviveWitheredTree_Success() public {
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        (, , uint256 lastWatered, , ) = treeGrowth.getTreeData(1);

        vm.warp(lastWatered + 6 days);

        vm.prank(user1);
        treeGrowth.reviveWitheredTree{value: REVIVAL_COST}(1);

        (, , uint256 newLastWatered, uint8 currentStage, ) = treeGrowth
            .getTreeData(1);
        assertEq(currentStage, 1, "Tree should be reset to sapling");
        assertEq(
            newLastWatered,
            block.timestamp,
            "Last watered should be updated"
        );
    }

    function testAfterReachingNewStage() public {
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);
        (, uint256 planted, , uint8 newStage, uint16 wateringCount) = treeGrowth
            .getTreeData(1);

        vm.warp(planted + 120 days);

        vm.startPrank(user1);
        for (uint256 i = 0; i < 49; i++) {
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
            treeGrowth.wateringTree{value: WATERING_COST}(1);
        }
        vm.stopPrank();
        (
            ,
            uint256 plantedTimestamp,
            ,
            uint8 stage,
            uint16 finalCount
        ) = treeGrowth.getTreeData(1);

        assertEq(stage, 4, "Tree should be ancient tree");
        assertEq(finalCount, 50, "Should have 50 waterings");
    }

    function testCalculateTypeOfTreeToMint() public {
        vm.warp(block.timestamp + 30 days);

        // The 15th watering should emit stage 2
        for (uint256 i = 0; i < 14; i++) {
            vm.prank(user3);
            treeGrowth.wateringTree{value: WATERING_COST}(9);
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }
        // 15th watering should trigger young tree stage
        vm.prank(user3);
        treeGrowth.wateringTree{value: WATERING_COST}(9);
        (, , , uint8 currentStage, ) = treeGrowth.getTreeData(1);

        (
            TreeNFTCollection.TreeType treeType,
            uint256 plantedTimestamp,
            uint256 lastWateredTimestamp,
            uint8 growthStage,
            uint16 wateringCount
        ) = treeGrowth.getTreeData(9);

        uint256 newTokenId = treeGrowth.calculateTypeOfTreeToMint(9);
        assertEq(
            newTokenId,
            9 + growthStage - 1,
            "New token ID should be correct"
        );
    }

    function testMintNextStageToken() public {
        // Setup: Get user1's summer tree to stage 2 (young tree)
        vm.warp(block.timestamp + 30 days);

        // Water 14 times (15th watering will trigger stage 2)
        for (uint256 i = 0; i < 14; i++) {
            vm.prank(user1);
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        // Verify tree is still at stage 1
        (, , , uint8 stageBefore, ) = treeGrowth.getTreeData(1);
        assertEq(stageBefore, 1, "Tree should still be at stage 1");

        // 15th watering should trigger stage progression and mint next stage token
        vm.expectEmit(true, false, false, false);
        emit NextStageNFTMinted(user1, 4); // Summer tree stage 2 should be token ID 4

        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        // Verify original tree progressed to stage 2
        (, , , uint8 stageAfter, ) = treeGrowth.getTreeData(1);
        assertEq(stageAfter, 2, "Original tree should be at stage 2");

        // Verify new token was minted
        assertEq(
            treeGrowth.ownerOf(4),
            user1,
            "User1 should own the new token"
        );
        assertEq(treeGrowth.balanceOf(user1), 2, "User1 should have 2 tokens");
    }

    function testMintNextStageTokenDifferentTreeTypes() public {
        vm.warp(block.timestamp + 30 days);

        // Calculate expected token IDs based on your logic:
        // Summer: baseTokenId = 1, stage 2 -> 1 + 2 - 1 = 2
        // Snow: baseTokenId = 5, stage 2 -> 5 + 2 - 1 = 6
        // Autumn: baseTokenId = 9, stage 2 -> 9 + 2 - 1 = 10

        // Test Summer tree (tokenId 1) -> should mint tokenId 2
        for (uint256 i = 0; i < 15; i++) {
            vm.prank(user1);
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        assertEq(
            treeGrowth.ownerOf(2),
            user1,
            "Summer tree should mint token 2"
        );

        // Test Snow tree (tokenId 2) -> should mint tokenId 6
        for (uint256 i = 0; i < 15; i++) {
            vm.prank(user2);
            treeGrowth.wateringTree{value: WATERING_COST}(5);
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        assertEq(treeGrowth.ownerOf(6), user2, "Snow tree should mint token 6");

        // Test Autumn tree (tokenId 3) -> should mint tokenId 10
        for (uint256 i = 0; i < 15; i++) {
            vm.prank(user3);
            treeGrowth.wateringTree{value: WATERING_COST}(9);
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        assertEq(
            treeGrowth.ownerOf(10),
            user3,
            "Autumn tree should mint token 10"
        );
    }

    event NextStageNFTMinted(address indexed to, uint256 newTokenId);
}
