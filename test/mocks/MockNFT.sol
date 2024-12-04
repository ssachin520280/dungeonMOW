// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../../lib/forge-std/src/mocks/MockERC721.sol";

contract MyMockNFT is MockERC721 {
    constructor(string memory name, string memory symbol) {
        initialize(name, symbol);
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        require(msg.sender == ownerOf(tokenId), "NOT_OWNER");
        _burn(tokenId);
    }
}