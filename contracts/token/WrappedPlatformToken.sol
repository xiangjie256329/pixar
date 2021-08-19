// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import './WrappedToken.sol';

contract WrappedPlatformToken is WrappedToken {
    uint256 public Cap = 200000000*10**18;
    constructor() public WrappedToken(0x4936e6A6A989b4B6101D7Bd70a8e494649853360, "Rzry", "Rzry",Cap) {

    }
}
