// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

error Only__Owner();

contract Whitelist {
    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) private addressToIndex;
    uint256 public immutable maxWhitelistedAddresses;
    address[] public whitelistedAddresses;
    address public immutable initialOwner;

    event removedFromWhitelist(address indexed _address);
    event addedToWhitelist(address indexed _address);

    constructor(uint256 _maxWhitelistedAddresses) {
        initialOwner = msg.sender;
        maxWhitelistedAddresses = _maxWhitelistedAddresses;
    }

    function addToWhitelist(address _address) external {
        require(!isWhitelisted[_address], "Address is already whitelisted");
        require(whitelistedAddresses.length < maxWhitelistedAddresses, "Whitelist is already full");

        addressToIndex[_address] = whitelistedAddresses.length;
        whitelistedAddresses.push(_address);
        isWhitelisted[_address] = true;

        emit addedToWhitelist(_address);
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        require(isWhitelisted[_address], "Address is not whitelisted");
        uint256 indexToRemove = addressToIndex[_address];
        uint256 lastIndex = whitelistedAddresses.length - 1;

        if (indexToRemove != lastIndex) {
            address lastAddress = whitelistedAddresses[lastIndex];
            whitelistedAddresses[indexToRemove] = lastAddress;
            addressToIndex[lastAddress] = indexToRemove;
        }

        whitelistedAddresses.pop();
        delete addressToIndex[_address];
        isWhitelisted[_address] = false;
        emit removedFromWhitelist(_address);
    }

    function getWhitelistedAddresses() external view returns (address[] memory) {
        return whitelistedAddresses;
    }

    modifier onlyOwner() {
        if (msg.sender != initialOwner) revert Only__Owner();
        _;
    }
}
