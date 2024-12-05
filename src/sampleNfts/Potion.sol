// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract Potion is ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("Potion", "PTN") {}

    function mint() public returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        return tokenId;
    }
}
