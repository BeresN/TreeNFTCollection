// SPDX-License-Identifier: UNLICENSED
/*pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/TreeGrowthStages.sol";
import "../src/TreeNFTCollection.sol";
import "../src/Whitelist.sol";

contract TreeGrowthStagesTest is Test {
    TreeGrowthStages public treeGrowth;
    Whitelist public whitelist;
    TreeNFTCollection public nftCollection;

    address public owner;
    address public user1;
    address public user2;
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
        nonOwner = makeAddr("nonOwner");

        // Give users some ETH
        vm.deal(owner, 10 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
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
        vm.stopPrank();

        // Mint NFTs for testing
        vm.prank(user1);
        treeGrowth.mint{value: NFT_PRICE}(user1);

        vm.prank(user2);
        treeGrowth.mint{value: NFT_PRICE}(user2);
    }

    // Constructor and Basic Tests
    function testInheritance() public {
        // Verify the contract properly inherits NFTCollection functionality
        assertEq(treeGrowth.ownerOf(1), user1);
        assertEq(treeGrowth.ownerOf(2), user2);
        assertEq(treeGrowth.balanceOf(user1), 1);
        assertEq(treeGrowth.balanceOf(user2), 1);
    }

    // Watering Tests
    function testWateringTreeBasic() public {
        uint256 wateringCost = treeGrowth.wateringCost();
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit treeGrowthCalculation(1, 0, 1); // Should remain stage 0 after first watering
        treeGrowth.wateringTree{value: wateringCost}(1);

        // Verify tree data updated
        (, uint256 lastWatered, uint8 stage, uint16 count) = treeGrowth
            .getTreeData(1);
        assertEq(lastWatered, block.timestamp);
        assertEq(stage, 0);
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
        (uint256 plantedTimestamp, uint256 lastWateredTimestamp, uint8 growthStage, uint16 count) =
            treeGrowth.getTreeData(1);
        assertEq(plantedTimestamp, 1);
        assertEq(lastWateredTimestamp, 0);
        assertEq(growthStage, 0);
        assertEq(count, 0);

        vm.prank(user1);
        treeGrowth.wateringTree{value: wateringCost}(1);

        // Fast forward past cooldown
        vm.warp(block.timestamp + Cooldown);

        // Second watering should work
        vm.prank(user1);
        treeGrowth.wateringTree{value: wateringCost}(1);

        (,,, count) = treeGrowth.getTreeData(1);
        assertEq(count, 2);
    }

    // Growth Stage Calculation Tests
    function testGrowthStagesSeedling() public {
        // New tree should be seedling (stage 0)
        vm.startPrank(user1);

        (, , uint8 stage, ) = treeGrowth.getTreeData(1);
        assertEq(stage, 0);

        // Water a few times but not enough to advance
        for (uint256 i = 0; i < 4; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }
        vm.stopPrank();

        (, , stage, ) = treeGrowth.getTreeData(1);
        assertEq(stage, 0); // Still seedling
    }

    function testGrowthStagesSapling() public {
        vm.startPrank(user1);

        // Fast forward 1 week
        vm.warp(block.timestamp + 7 days);

        // Water 5 times to reach sapling stage
        for (uint256 i = 0; i < 5; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            if (i < 4) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        vm.stopPrank();

        (, , uint8 stage, uint16 count) = treeGrowth.getTreeData(1);
        assertEq(stage, 1); // Sapling
        assertEq(count, 5);
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

        (, , uint8 stage, uint16 count) = treeGrowth.getTreeData(1);
        assertEq(stage, 2); // Young tree
        assertEq(count, 15);
    }

    function testGrowthStagesMatureTree() public {
        vm.startPrank(user1);

        // Fast forward 6 months
        vm.warp(block.timestamp + 180 days);

        // Water 50 times to reach mature tree stage
        for (uint256 i = 0; i < 50; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            if (i < 49) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        vm.stopPrank();

        (, , uint8 stage, uint16 count) = treeGrowth.getTreeData(1);
        assertEq(stage, 3); // Mature tree
        assertEq(count, 50);
    }

    function testGrowthStagesAncientTree() public {
        vm.startPrank(user1);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        // Water 100 times to reach ancient tree stage
        for (uint256 i = 0; i < 100; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            if (i < 99) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        vm.stopPrank();

        (, , uint8 stage, uint16 count) = treeGrowth.getTreeData(1);
        assertEq(stage, 4); // Ancient tree
        assertEq(count, 100);
    }

    // Edge Cases for Growth Stages
    function testGrowthStageRequiresBothAgeAndWatering() public {
        vm.startPrank(user1);

        // Test sapling requirements: 7+ days AND 5+ waterings

        // Only age, no watering
        vm.warp(block.timestamp + 10 days);
        treeGrowth.wateringTree{value: WATERING_COST}(1);
        (, , uint8 stage, ) = treeGrowth.getTreeData(1);
        assertEq(stage, 0); // Still seedling (only 1 watering)

        // Reset and test only watering, no age
        vm.stopPrank();

        // Mint new tree for clean test
        address user3 = makeAddr("user3");
        vm.deal(user3, 1 ether);
        vm.prank(owner);
        whitelist.addToWhitelist(user3);
        vm.prank(user3);
        treeGrowth.mint{value: NFT_PRICE}(user3);

        vm.startPrank(user3);
        // Water 5 times but no time passed
        for (uint256 i = 0; i < 5; i++) {
            treeGrowth.wateringTree{value: WATERING_COST}(3);
            if (i < 4) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        (, , stage, ) = treeGrowth.getTreeData(3);
        assertEq(stage, 0); // Still seedling (not enough age)

        vm.stopPrank();
    }

    function testGrowthStageNeverDowngrades() public {
        // Advance to sapling
        vm.warp(block.timestamp + 7 days);
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            if (i < 4) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        (,, uint8 stage,) = treeGrowth.getTreeData(1);
        assertEq(stage, 1); // Sapling

        // Continue watering but don't advance time enough for next stage
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            if (i < 4) vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }
        vm.prank(user1);
        (,, stage,) = treeGrowth.getTreeData(1);
        assertEq(stage, 1); // Should remain sapling, never downgrade
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
        (, , , uint16 count) = treeGrowth.getTreeData(1);
        assertEq(count, 1);
    }

    // Integration Tests
    function testMultipleUsersWateringTrees() public {
        // User1 waters their tree
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        // User2 waters their tree
        vm.prank(user2);
        treeGrowth.wateringTree{value: WATERING_COST}(2);

        // Check both trees were updated independently
        (, , , uint16 count1) = treeGrowth.getTreeData(1);
        (, , , uint16 count2) = treeGrowth.getTreeData(2);

        assertEq(count1, 1);
        assertEq(count2, 1);
    }

    // Fuzz Tests
    function testFuzzWateringAmount(uint256 payment) public {
        vm.assume(payment >= WATERING_COST && payment <= 1 ether);

        vm.deal(user1, payment);
        vm.prank(user1);
        treeGrowth.wateringTree{value: payment}(1);

        (, , , uint16 count) = treeGrowth.getTreeData(1);
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
        // Fast forward and water to reach sapling
        vm.warp(block.timestamp + 7 days);

        // The 5th watering should emit stage 1
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(user1);
            treeGrowth.wateringTree{value: WATERING_COST}(1);
            vm.warp(block.timestamp + WATERING_COOLDOWN + 1);
        }

        // 5th watering should trigger sapling stage
        vm.expectEmit(true, false, false, true);
        emit treeGrowthCalculation(1, 1, 5);
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);
    }

    function testWitheredTreeHandle() public {
        // Make tree withered first
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        (uint256 planted, , , ) = treeGrowth.getTreeData(1);
        vm.warp(planted + 7 days);
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        (, , uint8 stage, ) = treeGrowth.getTreeData(1);
        assertEq(stage, 5);
    }

    function testReviveWitheredTree_Success() public {
        // First make tree withered (following your logic)
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        (uint256 planted, , , uint16 wateringCount) = treeGrowth.getTreeData(1);

        // Fast forward and water to trigger withered state
        vm.warp(planted + 8 days);
        vm.prank(user1);
        treeGrowth.wateringTree{value: WATERING_COST}(1);

        // Verify tree is withered
        (, , uint8 stage, ) = treeGrowth.getTreeData(1);
        assertEq(stage, 0, "Tree should be withered");

        // Revive the tree
        vm.expectEmit(true, false, false, true);
        emit treeGrowthCalculation(1, 1, wateringCount + 1); // Should reset to stage 0

        vm.prank(user1);
        treeGrowth.reviveWitheredTree{value: REVIVAL_COST}(1);

        // Check tree is revived
        (, uint256 newLastWatered, uint8 newStage, ) = treeGrowth.getTreeData(
            1
        );
        assertEq(newStage, 1, "Tree should be reset to seedling");
        assertEq(
            newLastWatered,
            block.timestamp,
            "Last watered should be updated"
        );
    }
}
