// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Whitelist is Ownable {
    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) private addressToIndex;
    uint256 public immutable maxWhitelistedAddresses;
    address[] public whitelistedAddresses;

    event removedFromWhitelist(address indexed _address);
    event addedToWhitelist(address indexed _address);

    constructor(address initialOwner, uint256 _maxWhitelistedAddresses) Ownable(initialOwner) {
        maxWhitelistedAddresses = _maxWhitelistedAddresses;
    }

    function addToWhitelist(address _address) external onlyOwner{
        require(!isWhitelisted[_address], "Address is already whitelisted");
        require(whitelistedAddresses.length == maxWhitelistedAddresses, "Whitelist is already full");
        isWhitelisted[_address] = true;
        whitelistedAddresses.push(_address);
        emit addedToWhitelist(_address);
    }

    function removeFromWhitelist(
        address _address
    ) external onlyOwner {
        require(isWhitelisted[_address], "Address is not whitelisted");
        isWhitelisted[_address] = false;
        uint256 indexToRemove = addressToIndex[_address];
        uint256 lastIndex = whitelistedAddresses.length - 1;

        if(indexToRemove != lastIndex){
            address lastAddress = whitelistedAddresses[lastIndex];
            whitelistedAddresses[indexToRemove] = lastAddress;
            addressToIndex[lastAddress] = indexToRemove;
         }
         
        whitelistedAddresses.pop();
        emit removedFromWhitelist(_address);
    }
}