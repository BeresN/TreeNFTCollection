// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Whitelist is Ownable {
    mapping(address => bool) isWhitelisted;
    mapping(address => uint256) whitelistCount;

    address[] public whitelistedAddresses;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function addToWhitelist(address _address) external {
        require(!isWhitelisted[_address], "Address is already whitelisted");
        isWhitelisted[_address] = true;
        whitelistedAddresses.push(_address);
        whitelistCount[_address]++;
    }

    function removeFromWhitelist(
        address _address
    ) external onlyOwner returns (address removed) {
        require(isWhitelisted[_address], "Address is not whitelisted");
        isWhitelisted[_address] = false;
        whitelistCount[_address] = 0;

        uint256 iToRemove = 0;
        bool found = false;

        for(uint256 i = 0; i < whitelistedAddresses.length; i++){
            if(whitelistedAddresses[i] = _address){
                iToRemove = i;
                found = true;
                break;
            }
        }
        require(found, "address not found in array");
        if(index != whitelistedAddresses.length - 1) {
            whitelistedAddresses[iToRemove] = whitelistedAddresses[whitelistedAddresses.length - 1];
        }
        whitelistedAddresses.pop();
        return _address;
    }
