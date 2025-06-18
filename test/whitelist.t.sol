// SPDX-License-Identifier: UNLICENSED
/*pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/Whitelist.sol";

contract WhitelistTest is Test {
    Whitelist public whitelist;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public nonOwner;

    uint256 public constant MAX_WHITELIST_SIZE = 3;

    event removedFromWhitelist(address indexed _address);
    event addedToWhitelist(address indexed _address);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        nonOwner = makeAddr("nonOwner");

        vm.prank(owner);
        whitelist = new Whitelist(MAX_WHITELIST_SIZE);
    }

    // Constructor Tests
    function testConstructor() public {
        assertEq(whitelist.maxWhitelistedAddresses(), MAX_WHITELIST_SIZE);

        address[] memory addresses = whitelist.getWhitelistedAddresses();
        assertEq(addresses.length, 0);
    }

    function testConstructorWithDifferentMaxSize() public {
        uint256 customMaxSize = 10;
        vm.prank(owner);
        Whitelist customWhitelist = new Whitelist(customMaxSize);

        assertEq(customWhitelist.maxWhitelistedAddresses(), customMaxSize);
    }

    // Add to Whitelist Tests
    function testAddToWhitelist() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit addedToWhitelist(user1);
        whitelist.addToWhitelist(user1);

        assertTrue(whitelist.isWhitelisted(user1));

        address[] memory addresses = whitelist.getWhitelistedAddresses();
        assertEq(addresses.length, 1);
        assertEq(addresses[0], user1);
    }

    function testAddMultipleToWhitelist() public {
        vm.startPrank(owner);

        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);

        vm.stopPrank();

        assertTrue(whitelist.isWhitelisted(user1));
        assertTrue(whitelist.isWhitelisted(user2));
        assertTrue(whitelist.isWhitelisted(user3));

        address[] memory addresses = whitelist.getWhitelistedAddresses();
        assertEq(addresses.length, 3);
        assertEq(addresses[0], user1);
        assertEq(addresses[1], user2);
        assertEq(addresses[2], user3);
    }

    function testAddToWhitelistRevertsWhenNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        whitelist.addToWhitelist(user1);
    }

    function testAddToWhitelistRevertsWhenAlreadyWhitelisted() public {
        vm.startPrank(owner);
        whitelist.addToWhitelist(user1);

        vm.expectRevert("Address is already whitelisted");
        whitelist.addToWhitelist(user1);
        vm.stopPrank();
    }

    function testAddToWhitelistRevertsWhenFull() public {
        vm.startPrank(owner);

        // Fill the whitelist to capacity
        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);

        // Try to add one more
        vm.expectRevert("Whitelist is already full");
        whitelist.addToWhitelist(user4);

        vm.stopPrank();
    }

    // Remove from Whitelist Tests
    function testRemoveFromWhitelistSingleAddress() public {
        // Add user first
        vm.startPrank(owner);
        whitelist.addToWhitelist(user1);

        // Verify added
        assertTrue(whitelist.isWhitelisted(user1));
        assertEq(whitelist.getWhitelistedAddresses().length, 1);

        // Remove user
        vm.expectEmit(true, false, false, false);
        emit removedFromWhitelist(user1);
        whitelist.removeFromWhitelist(user1);

        vm.stopPrank();

        // Verify removed
        assertFalse(whitelist.isWhitelisted(user1));
        assertEq(whitelist.getWhitelistedAddresses().length, 0);
    }

    function testRemoveFromWhitelistMiddleAddress() public {
        // This test will likely fail due to the bug in the contract
        // The addressToIndex mapping is never set when adding addresses
        vm.startPrank(owner);

        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);

        // Try to remove middle address (user2)
        // This should work but likely won't due to addressToIndex bug
        whitelist.removeFromWhitelist(user2);

        vm.stopPrank();

        assertFalse(whitelist.isWhitelisted(user2));

        address[] memory addresses = whitelist.getWhitelistedAddresses();
        assertEq(addresses.length, 2);

        // Check that the remaining addresses are correct
        // Note: Due to the swap-and-pop mechanism, user3 should be moved to position 1
        bool foundUser1 = false;
        bool foundUser3 = false;

        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == user1) foundUser1 = true;
            if (addresses[i] == user3) foundUser3 = true;
        }

        assertTrue(foundUser1);
        assertTrue(foundUser3);
    }

    function testRemoveFromWhitelistLastAddress() public {
        vm.startPrank(owner);

        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);

        // Remove last address
        whitelist.removeFromWhitelist(user3);

        vm.stopPrank();

        assertFalse(whitelist.isWhitelisted(user3));
        assertTrue(whitelist.isWhitelisted(user1));
        assertTrue(whitelist.isWhitelisted(user2));

        address[] memory addresses = whitelist.getWhitelistedAddresses();
        assertEq(addresses.length, 2);
        assertEq(addresses[0], user1);
        assertEq(addresses[1], user2);
    }

    function testRemoveFromWhitelistRevertsWhenNotOwner() public {
        vm.prank(owner);
        whitelist.addToWhitelist(user1);

        vm.prank(nonOwner);
        vm.expectRevert();
        whitelist.removeFromWhitelist(user1);
    }

    // NOTE: This test should now work correctly with the fixed contract
    function testRemoveNonWhitelistedAddressReverts() public {
        // Now the contract properly checks if address is whitelisted
        vm.prank(owner);
        vm.expectRevert("Address is not whitelisted");
        whitelist.removeFromWhitelist(user1);
    }

    // View Function Tests
    function testGetWhitelistedAddresses() public {
        address[] memory emptyAddresses = whitelist.getWhitelistedAddresses();
        assertEq(emptyAddresses.length, 0);

        vm.startPrank(owner);
        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        vm.stopPrank();

        address[] memory addresses = whitelist.getWhitelistedAddresses();
        assertEq(addresses.length, 2);
        assertEq(addresses[0], user1);
        assertEq(addresses[1], user2);
    }

    function testIsWhitelistedReturnsFalseForNonWhitelisted() public {
        assertFalse(whitelist.isWhitelisted(user1));
        assertFalse(whitelist.isWhitelisted(user2));
        assertFalse(whitelist.isWhitelisted(address(0)));
    }

    // Edge Cases and Integration Tests
    function testAddAndRemoveSequence() public {
        vm.startPrank(owner);

        // Add users
        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);

        // Remove first user
        whitelist.removeFromWhitelist(user1);

        // Add another user (should work since we're under limit again)
        whitelist.addToWhitelist(user3);

        vm.stopPrank();

        assertFalse(whitelist.isWhitelisted(user1));
        assertTrue(whitelist.isWhitelisted(user2));
        assertTrue(whitelist.isWhitelisted(user3));

        address[] memory addresses = whitelist.getWhitelistedAddresses();
        assertEq(addresses.length, 2);
    }

    function testFillAndEmptyWhitelist() public {
        vm.startPrank(owner);

        // Fill to capacity
        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);

        assertEq(whitelist.getWhitelistedAddresses().length, MAX_WHITELIST_SIZE);

        // Empty completely
        whitelist.removeFromWhitelist(user1);
        whitelist.removeFromWhitelist(user2);
        whitelist.removeFromWhitelist(user3);

        vm.stopPrank();

        assertEq(whitelist.getWhitelistedAddresses().length, 0);
        assertFalse(whitelist.isWhitelisted(user1));
        assertFalse(whitelist.isWhitelisted(user2));
        assertFalse(whitelist.isWhitelisted(user3));
    }

    // Fuzz Tests
    function testFuzzAddToWhitelist(address randomAddress) public {
        vm.assume(randomAddress != address(0));
        vm.assume(randomAddress != owner);

        vm.prank(owner);
        whitelist.addToWhitelist(randomAddress);

        assertTrue(whitelist.isWhitelisted(randomAddress));

        address[] memory addresses = whitelist.getWhitelistedAddresses();
        assertEq(addresses.length, 1);
        assertEq(addresses[0], randomAddress);
    }

    function testFuzzMaxWhitelistSize(uint256 maxSize) public {
        vm.assume(maxSize > 0 && maxSize <= 1000); // Reasonable bounds

        vm.prank(owner);
        Whitelist fuzzWhitelist = new Whitelist(maxSize);

        assertEq(fuzzWhitelist.maxWhitelistedAddresses(), maxSize);
    }

    // Gas Usage Tests
    function testGasUsageAddToWhitelist() public {
        uint256 gasBefore = gasleft();
        vm.prank(owner);
        whitelist.addToWhitelist(user1);
        uint256 gasUsed = gasBefore - gasleft();

        // Gas usage should be reasonable (adjust threshold as needed)
        assertLt(gasUsed, 100000);
    }

    // Test the fixes work correctly
    function testFixedAddressToIndexMapping() public {
        vm.startPrank(owner);

        whitelist.addToWhitelist(user1);
        whitelist.addToWhitelist(user2);
        whitelist.addToWhitelist(user3);

        // Remove middle address - this should work correctly now
        whitelist.removeFromWhitelist(user2);

        // Verify state is correct
        assertTrue(whitelist.isWhitelisted(user1));
        assertFalse(whitelist.isWhitelisted(user2));
        assertTrue(whitelist.isWhitelisted(user3));

        address[] memory addresses = whitelist.getWhitelistedAddresses();
        assertEq(addresses.length, 2);

        // user3 should have been moved to index 1 (where user2 was)
        assertEq(addresses[0], user1);
        assertEq(addresses[1], user3);

        vm.stopPrank();
    }

    function testRemoveNonWhitelistedAddressNowReverts() public {
        vm.prank(owner);
        vm.expectRevert("Address is not whitelisted");
        whitelist.removeFromWhitelist(user1);
    }
}
