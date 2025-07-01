// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import "../../src/CalculateStage.sol";
import "../../src/Whitelist.sol";

contract TreeGrowthStagesFuzzTest is Test {
    TreeGrowthStages public treeContract;
    Whitelist public whitelist;
    
    address public owner;
    address public user1;
    address public user2;
    
    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 public constant WATERING_COST = 0.0004 ether;
    uint256 public constant WATERING_COOLDOWN = 1 days;
    uint256 public constant WITHER_TIME = 5 days;
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        vm.prank(owner);
        whitelist = new Whitelist(10);
        
        vm.prank(owner);
        treeContract = new TreeGrowthStages(address(whitelist));
        
        vm.startPrank(owner);
        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_WateringReentrancyProtection(uint256 payment) public {
        vm.assume(payment >= WATERING_COST && payment <= 100 ether);
        
        // Mint first
        vm.prank(user1);
        treeContract.mint{value: MINT_PRICE}(user1, TreeNFTCollection.TreeType.Summer);
        
        vm.deal(user1, payment);
        vm.prank(user1);
        treeContract.wateringTree{value: payment}(1);
        
        vm.prank(user1);
        vm.expectRevert("tree was already watered");
        treeContract.wateringTree{value: payment}(1);
    }
    
    function testFuzz_PaymentManipulation(uint256 payment, uint256 extraValue) public {
        vm.assume(payment >= WATERING_COST && payment <= 10 ether);
        vm.assume(extraValue <= 100 ether);
        
        vm.prank(user1);
        treeContract.mint{value: MINT_PRICE}(user1, TreeNFTCollection.TreeType.Summer);
        
        uint256 initialBalance = address(treeContract).balance;
        
        vm.deal(user1, payment + extraValue);
        vm.prank(user1);
        treeContract.wateringTree{value: payment}(1);
        
        assertEq(address(treeContract).balance, initialBalance + payment);
    }
    
    function testFuzz_UnauthorizedWatering(address attacker) public {
        vm.assume(attacker != user1 && attacker != address(0));
        vm.assume(attacker != owner);
        
        vm.prank(user1);
        treeContract.mint{value: MINT_PRICE}(user1, TreeNFTCollection.TreeType.Summer);
        
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        vm.expectRevert("only owner can water the tree");
        treeContract.wateringTree{value: WATERING_COST}(1);
    }

    function testFuzz_GrowthStageCalculation(uint256 timeOffset, uint16 wateringCount) public {
        vm.assume(timeOffset <= 365 days); 
        vm.assume(wateringCount <= 200); 
        
        vm.prank(user1);
        treeContract.mint{value: MINT_PRICE}(user1, TreeNFTCollection.TreeType.Summer);
        
 
        vm.warp(block.timestamp + timeOffset);
        
     
        vm.store(
            address(treeContract),
            keccak256(abi.encode(1, 32)), 
            bytes32(uint256(wateringCount))
        );
        
        vm.prank(user1);
        treeContract.wateringTree{value: WATERING_COST}(1);
        
        (, , , uint8 growthStage, ) = treeContract.getTreeData(1);
        
   
        uint256 ageInDays = timeOffset / 1 days;
        if (ageInDays >= 120 && wateringCount >= 50) {
            assertEq(growthStage, 4);
        } else if (ageInDays >= 60 && wateringCount >= 30) {
            assertEq(growthStage, 3);
        } else if (ageInDays >= 30 && wateringCount >= 15) {
            assertEq(growthStage, 2);
        } else {
            assertEq(growthStage, 1);
        }
    }
    

    function testFuzz_WitheringLogic(uint256 timeGap) public {
        vm.assume(timeGap <= 365 days);
        
        vm.prank(user1);
        treeContract.mint{value: MINT_PRICE}(user1, TreeNFTCollection.TreeType.Summer);
        

        vm.prank(user1);
        treeContract.wateringTree{value: WATERING_COST}(1);
        

        vm.warp(block.timestamp + timeGap);
        
        if (timeGap > WITHER_TIME) {
       
            vm.prank(user1);
            vm.expectRevert("Tree is withered, revive first");
            treeContract.wateringTree{value: WATERING_COST}(1);
        } else {
       
            if (timeGap >= WATERING_COOLDOWN) {
                vm.prank(user1);
                treeContract.wateringTree{value: WATERING_COST}(1);
            }
        }
    }
    
    

    function testFuzz_RevivalCost(uint256 payment) public {
        vm.assume(payment <= 100 ether);
        
        vm.prank(user1);
        treeContract.mint{value: MINT_PRICE}(user1, TreeNFTCollection.TreeType.Summer);
        

        vm.prank(user1);
        treeContract.wateringTree{value: WATERING_COST}(1);
        
        vm.warp(block.timestamp + WITHER_TIME + 1);
        
        vm.deal(user1, payment);
        vm.prank(user1);
        
        if (payment >= WATERING_COST * 5) {
            treeContract.reviveWitheredTree{value: payment}(1);
            (, , , uint8 growthStage, ) = treeContract.getTreeData(1);
            assertEq(growthStage, 1); 
        } else {
            vm.expectRevert("insufficient amount");
            treeContract.reviveWitheredTree{value: payment}(1);
        }
    }
    
    

    function testFuzz_NextStageNFTMinting(uint8 currentStage, uint8 newStage) public {
        vm.assume(currentStage >= 1 && currentStage <= 4);
        vm.assume(newStage >= 1 && newStage <= 4);
        vm.assume(newStage > currentStage); 
        
        vm.prank(user1);
        treeContract.mint{value: MINT_PRICE}(user1, TreeNFTCollection.TreeType.Summer);
   
        bytes32 stageSlot = keccak256(abi.encode(1, 32));
        vm.store(address(treeContract), stageSlot, bytes32(uint256(currentStage)));
        
   
        uint256 initialSupply = 1; 
        
        vm.prank(user1);
        uint256 newTokenId = treeContract.mintNextStageToken{value: 0}(1);
        
        assertEq(newTokenId, 6);
        assertEq(treeContract.ownerOf(newTokenId), user1);
    }
    

    
  
    function testFuzz_GasConsumption(uint256 tokenId, uint256 payment) public {
        vm.assume(tokenId >= 1 && tokenId <= 5);
        vm.assume(payment >= WATERING_COST && payment <= 1 ether);
        
     
        if (tokenId <= 3) {
            vm.prank(user1);
            treeContract.mint{value: MINT_PRICE}(user1, TreeNFTCollection.TreeType.Summer);
            
            uint256 gasBefore = gasleft();
            vm.prank(user1);
            treeContract.wateringTree{value: payment}(1);
            uint256 gasUsed = gasBefore - gasleft();
            
        
            assertTrue(gasUsed < 200000, "Gas usage too high");
        }
    }
    

    
   
    function testFuzz_ExtremeTimestamps(uint256 futureTime) public {
        vm.assume(futureTime <= type(uint40).max); 
        vm.assume(futureTime > block.timestamp);
        
        vm.prank(user1);
        treeContract.mint{value: MINT_PRICE}(user1, TreeNFTCollection.TreeType.Summer);
        

        vm.warp(futureTime);
        
     
        vm.prank(user1);
        treeContract.wateringTree{value: WATERING_COST}(1);
        
        (, uint256 planted, , , ) = treeContract.getTreeData(1);
        assertTrue(planted < futureTime);
    }
    

    function testFuzz_TreeTypeCombinations(uint8 treeTypeInt) public {
        TreeNFTCollection.TreeType treeType;
        
        if (treeTypeInt % 3 == 0) {
            treeType = TreeNFTCollection.TreeType.Summer;
        } else if (treeTypeInt % 3 == 1) {
            treeType = TreeNFTCollection.TreeType.Snow;
        } else {
            treeType = TreeNFTCollection.TreeType.Autumn;
        }
        
        vm.prank(user1);
        treeContract.mint{value: MINT_PRICE}(user1, treeType);
        
        (TreeNFTCollection.TreeType storedType, , , , ) = treeContract.getTreeData(1);
        assertEq(uint8(storedType), uint8(treeType));
    }
}