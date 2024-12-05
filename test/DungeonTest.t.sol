// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "../lib/forge-std/src/Test.sol";
import {DeployDungeonMOW} from "../script/DeployDungeonMOW.s.sol";
import {DungeonMOW, NotDungeonOwner, NFTDoesNotExist, DungeonDoesNotExist, NotItemOwner, TermsNotSigned, TermsExpired, IncorrectPaymentAmount} from "../src/Dungeon.sol";
import {Nft1} from "../src/sampleNfts/Nft1.sol";
import {Nft2} from "../src/sampleNfts/Nft2.sol";
import {Potion} from "../src/sampleNfts/Potion.sol";
import {Sword} from "../src/sampleNfts/Sword.sol";

contract DungeonTest is Test {
    DungeonMOW dungeonMOW;
    Nft1 nft1;
    Nft2 nft2;
    Sword sword;
    Potion potion;
    uint256 nft1Id;
    uint256 nft2Id;
    uint256 swordId;
    uint256 potionId;

    address public USER = makeAddr("user");
    address public NFT1_OWNER = makeAddr("nft1Owner");
    address public NFT2_OWNER = makeAddr("nft2Owner");
    address public SWORD_OWNER = makeAddr("swordOwner");
    address public POTION_OWNER = makeAddr("potionOwner");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() public {
        DeployDungeonMOW deployScript = new DeployDungeonMOW();
        dungeonMOW = deployScript.run();

        vm.startBroadcast();
        nft1 = new Nft1();
        nft2 = new Nft2();
        sword = new Sword();
        potion = new Potion();
        vm.stopBroadcast();

        vm.prank(NFT1_OWNER);
        nft1Id = nft1.mint();
        vm.prank(NFT2_OWNER);
        nft2Id = nft2.mint();
        vm.prank(SWORD_OWNER);
        swordId = sword.mint();
        vm.prank(POTION_OWNER);
        potionId = potion.mint();
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
        uint256 dungeonId = 0;
        uint256 charge = 0.5 ether;

        vm.prank(NFT1_OWNER);
        dungeonMOW.setLinkingCharge(address(nft1), nft1Id, dungeonId, charge);

        uint256 storedCharge = dungeonMOW.nftLinkingCharges(address(nft1), nft1Id, dungeonId);
        assertEq(storedCharge, charge);
    }

    function testSignTerms() public {
        uint256 dungeonId = 0;
        uint256 validityPeriod = 7200; // 2 hours

        vm.prank(NFT1_OWNER);
        dungeonMOW.signTerms(address(nft1), nft1Id, dungeonId, validityPeriod);

        bytes32 termsHash = dungeonMOW.nftTermsHashes(address(nft1), nft1Id, dungeonId);
        assert(termsHash != bytes32(0));
    }

    function testAddLinkedAsset() public {
        // Setup
        string memory metadataURI = "ipfs://example";
        uint256 dungeonId = 0;
        uint256 charge = 0.5 ether;
        uint256 validityPeriod = 7200;

        // Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(metadataURI);

        // Set linking charge and sign terms
        vm.prank(NFT1_OWNER);
        dungeonMOW.setLinkingCharge(address(nft1), nft1Id, dungeonId, charge);
        
        vm.prank(NFT1_OWNER);
        dungeonMOW.signTerms(address(nft1), nft1Id, dungeonId, validityPeriod);

        // Add linked asset
        vm.deal(USER, charge);
        vm.prank(USER);
        dungeonMOW.addLinkedAsset{value: charge}(dungeonId, address(nft1), nft1Id);

        // Check NFT1_OWNER received the payment
        assertEq(NFT1_OWNER.balance, charge);
    }

    function testImportItem() public {
        // Setup
        string memory metadataURI = "ipfs://example";
        uint256 dungeonId = 0;

        // Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(metadataURI);

        // Give sword to USER
        vm.prank(SWORD_OWNER);
        sword.transferFrom(SWORD_OWNER, USER, swordId);

        // Verify initial ownership
        assertEq(sword.ownerOf(swordId), USER);

        // Approve and import sword
        vm.startPrank(USER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId, address(sword), swordId);
        vm.stopPrank();

        // Verify:
        // 1. Dungeon contract owns the NFT
        // 2. SWORD_OWNER has actual ownership of the NFT
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(dungeonId, address(sword), swordId), USER);
    }

    function testExportItem() public {
        // Setup
        string memory metadataURI = "ipfs://example";
        uint256 dungeonId = 0;

        // Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(metadataURI);

        vm.startPrank(SWORD_OWNER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId, address(sword), swordId);

        // Verify dungeon contract owns the NFT after import
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));

        // Export sword
        dungeonMOW.exportItem(dungeonId, address(sword), swordId);
        vm.stopPrank();

        // Verify:
        // 1. SWORD_OWNER owns the NFT again
        // 2. Management rights in dungeon are cleared
        assertEq(sword.ownerOf(swordId), SWORD_OWNER);
        assertEq(dungeonMOW.dungeonTokenOwners(dungeonId, address(sword), swordId), address(0));
    }

    function testFailImportItemNotOwner() public {
        string memory metadataURI = "ipfs://example";
        uint256 dungeonId = 0;

        vm.prank(USER);
        dungeonMOW.createDungeon(metadataURI);

        // Try to import sword without owning it
        vm.startPrank(USER);
        sword.approve(address(dungeonMOW), swordId);
        vm.expectRevert("ERC721: transfer from incorrect owner");
        dungeonMOW.importItem(dungeonId, address(sword), swordId);
        vm.stopPrank();
    }

    function testFailExportItemNotOwner() public {
        string memory metadataURI = "ipfs://example";
        uint256 dungeonId = 0;

        vm.prank(USER);
        dungeonMOW.createDungeon(metadataURI);

        // Import sword as USER
        vm.prank(SWORD_OWNER);
        sword.transferFrom(SWORD_OWNER, USER, swordId);

        vm.startPrank(USER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId, address(sword), swordId);
        vm.stopPrank();

        // Try to export sword as different user
        vm.prank(SWORD_OWNER);
        vm.expectRevert(NotItemOwner.selector);
        dungeonMOW.exportItem(dungeonId, address(sword), swordId);
    }

    function testFailMoveItemBetweenDungeonsNotOwner() public {
        string memory metadataURI = "ipfs://example";
        uint256 dungeonId1 = 0;
        uint256 dungeonId2 = 1;

        // Create dungeons
        vm.startPrank(USER);
        dungeonMOW.createDungeon(metadataURI);
        dungeonMOW.createDungeon(metadataURI);
        vm.stopPrank();

        // Import sword to first dungeon
        vm.prank(SWORD_OWNER);
        sword.transferFrom(SWORD_OWNER, USER, swordId);

        vm.startPrank(USER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId1, address(sword), swordId);
        vm.stopPrank();

        // Try to move sword as different user
        vm.prank(SWORD_OWNER);
        vm.expectRevert(NotItemOwner.selector);
        dungeonMOW.moveItemBetweenDungeons(dungeonId1, dungeonId2, address(sword), swordId);
    }

    function testFailAddLinkedAssetIncorrectPayment() public {
        string memory metadataURI = "ipfs://example";
        uint256 dungeonId = 0;
        uint256 charge = 0.5 ether;
        uint256 validityPeriod = 7200;

        vm.prank(USER);
        dungeonMOW.createDungeon(metadataURI);

        vm.startPrank(NFT1_OWNER);
        dungeonMOW.setLinkingCharge(address(nft1), nft1Id, dungeonId, charge);
        dungeonMOW.signTerms(address(nft1), nft1Id, dungeonId, validityPeriod);
        vm.stopPrank();

        // Try to add linked asset with incorrect payment
        vm.deal(USER, charge);
        vm.prank(USER);
        // vm.expectRevert(IncorrectPaymentAmount.selector);
        dungeonMOW.addLinkedAsset{value: charge - 0.1 ether}(dungeonId, address(nft1), nft1Id);
    }

    function testMoveItemBetweenDungeons() public {
        // Setup
        string memory metadataURI = "ipfs://example";
        uint256 dungeonId1 = 0;
        uint256 dungeonId2 = 1;

        // Create dungeons
        vm.startPrank(USER);
        dungeonMOW.createDungeon(metadataURI);
        dungeonMOW.createDungeon(metadataURI);
        vm.stopPrank();

        vm.startPrank(SWORD_OWNER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId1, address(sword), swordId);

        // Verify initial state
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(dungeonId1, address(sword), swordId), SWORD_OWNER);

        // Move sword between dungeons
        dungeonMOW.moveItemBetweenDungeons(dungeonId1, dungeonId2, address(sword), swordId);
        vm.stopPrank();

        // Verify:
        // 1. Dungeon contract still owns the NFT
        // 2. Management rights moved to new dungeon
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(dungeonId1, address(sword), swordId), address(0));
        assertEq(dungeonMOW.dungeonTokenOwners(dungeonId2, address(sword), swordId), SWORD_OWNER);
    }
}
