// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "../lib/forge-std/src/Test.sol";
import {DeployDungeonMOW} from "../script/DeployDungeonMOW.s.sol";
import {DungeonMOW} from "../src/Dungeon.sol";
import {MyMockNFT} from "../test/mocks/MockNFT.sol";

contract DungeonTest is Test {
    DungeonMOW dungeonMOW;
    MyMockNFT mockNFT;

    address public USER = makeAddr("user");
    address public NFT_OWNER = makeAddr("nftOwner");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() public {
        DeployDungeonMOW deployScript = new DeployDungeonMOW();
        dungeonMOW = deployScript.run();

        mockNFT = new MyMockNFT("Mock NFT", "MNFT");
        mockNFT.mint(NFT_OWNER, 1);
    }

    function testCreateDungeon() public {
        string memory metadataURI = "ipfs://example";
        vm.prank(USER);
        dungeonMOW.createDungeon(metadataURI);

        DungeonMOW.Dungeon memory dungeon = dungeonMOW.getDungeon(0);
        assertEq(dungeon.owner, USER);
        assertEq(dungeon.metadataURI, metadataURI);
    }

    function testSetLinkingCharge() public {
        uint256 tokenId = 1;
        uint256 dungeonId = 0;
        uint256 charge = 0.5 ether;

        vm.prank(NFT_OWNER);
        dungeonMOW.setLinkingCharge(address(mockNFT), tokenId, dungeonId, charge);

        uint256 storedCharge = dungeonMOW.nftLinkingCharges(address(mockNFT), tokenId, dungeonId);
        assertEq(storedCharge, charge);
    }

    function testSignTerms() public {
        address nftContract = address(0x123);
        uint256 tokenId = 1;
        uint256 dungeonId = 0;
        uint256 validityPeriod = 7200; // 2 hours

        vm.prank(NFT_OWNER);
        dungeonMOW.signTerms(nftContract, tokenId, dungeonId, validityPeriod);

        bytes32 termsHash = dungeonMOW.nftTermsHashes(nftContract, tokenId, dungeonId);
        assert(termsHash != bytes32(0));
    }
} 