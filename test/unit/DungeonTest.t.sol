// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployDungeonMOW} from "../../script/DeployDungeonMOW.s.sol";
import {DungeonMOW} from "../../src/Dungeon.sol";
import {Nft1} from "../../src/sampleNfts/Nft1.sol";
import {Nft2} from "../../src/sampleNfts/Nft2.sol";
import {Potion} from "../../src/sampleNfts/Potion.sol";
import {Sword} from "../../src/sampleNfts/Sword.sol";

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
    address public USER2 = makeAddr("user2");
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
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        DungeonMOW.Dungeon memory dungeon = dungeonMOW.getDungeon(0);
        assertEq(dungeonMOW.ownerOf(dungeon.id), USER);
        assertEq(dungeon.metadata.mapHash, mapHash);
        assertEq(dungeon.metadata.dbUrl, dbUrl);
    }

    function testCreateDungeonEmptyStrings() public {
        string memory mapHash = "";
        string memory dbUrl = "";
        
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        DungeonMOW.Dungeon memory dungeon = dungeonMOW.getDungeon(0);
        assertEq(dungeonMOW.ownerOf(dungeon.id), USER);
        assertEq(dungeon.metadata.mapHash, mapHash);
        assertEq(dungeon.metadata.dbUrl, dbUrl);
    }

    function testCreateMultipleDungeons() public {
        string memory mapHash1 = "QmHash123";
        string memory dbUrl1 = "https://example.com/db1";
        string memory mapHash2 = "QmHash456";
        string memory dbUrl2 = "https://example.com/db2";
        
        vm.startPrank(USER);
        dungeonMOW.createDungeon(mapHash1, dbUrl1);
        dungeonMOW.createDungeon(mapHash2, dbUrl2);
        vm.stopPrank();

        DungeonMOW.Dungeon memory dungeon1 = dungeonMOW.getDungeon(0);
        DungeonMOW.Dungeon memory dungeon2 = dungeonMOW.getDungeon(1);
        
        assertEq(dungeonMOW.ownerOf(dungeon1.id), USER);
        assertEq(dungeon1.metadata.mapHash, mapHash1);
        assertEq(dungeon1.metadata.dbUrl, dbUrl1);
        
        assertEq(dungeonMOW.ownerOf(dungeon2.id), USER);
        assertEq(dungeon2.metadata.mapHash, mapHash2);
        assertEq(dungeon2.metadata.dbUrl, dbUrl2);
    }

    function testCreateSameDungeon() public {
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        
        vm.startPrank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);
        
        vm.expectRevert(DungeonMOW.DungeonAlreadyExists.selector);
        dungeonMOW.createDungeon(mapHash, dbUrl);
        vm.stopPrank();
    }

    function testCreateDungeonDifferentUsers() public {
        string memory mapHash1 = "QmHash123";
        string memory dbUrl1 = "https://example.com/db1";
        string memory mapHash2 = "QmHash456";
        string memory dbUrl2 = "https://example.com/db2";
        
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash1, dbUrl1);
        
        vm.prank(USER2);
        dungeonMOW.createDungeon(mapHash2, dbUrl2);

        DungeonMOW.Dungeon memory dungeon1 = dungeonMOW.getDungeon(0);
        DungeonMOW.Dungeon memory dungeon2 = dungeonMOW.getDungeon(1);
        
        assertEq(dungeonMOW.ownerOf(dungeon1.id), USER);
        assertEq(dungeonMOW.ownerOf(dungeon2.id), USER2);
    }

    function testTokenURIFormat() public {
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        string memory expectedJson = string(abi.encodePacked(
            '{"mapHash":"', 
            mapHash,
            '","dbUrl":"',
            dbUrl,
            '"}'
        ));
        
        assertEq(dungeonMOW.tokenURI(0), expectedJson);
    }

    function testTokenURINonexistentToken() public {
        vm.expectRevert(DungeonMOW.NFTDoesNotExist.selector);
        dungeonMOW.tokenURI(999);
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
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;
        uint256 charge = 0.5 ether;
        uint256 validityPeriod = 7200;

        // Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

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
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;

        // Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        // Verify initial ownership
        assertEq(sword.ownerOf(swordId), SWORD_OWNER);

        // Approve and import sword
        vm.startPrank(SWORD_OWNER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId, address(sword), swordId);
        vm.stopPrank();

        // Verify:
        // 1. Dungeon contract owns the NFT
        // 2. SWORD_OWNER has actual ownership of the NFT
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(address(sword), swordId, dungeonId), SWORD_OWNER);
    }

    function testExportItem() public {
        // Setup
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;

        // Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

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
        assertEq(dungeonMOW.dungeonTokenOwners(address(sword), swordId, dungeonId), address(0));
    }

    function testExportItemNotOwner() public {
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;

        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        vm.prank(SWORD_OWNER);
        sword.transferFrom(SWORD_OWNER, USER, swordId);

        vm.startPrank(USER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId, address(sword), swordId);
        vm.stopPrank();

        vm.prank(SWORD_OWNER);
        vm.expectRevert(DungeonMOW.NotItemOwner.selector);
        dungeonMOW.exportItem(dungeonId, address(sword), swordId);
    }

    function testMoveItemBetweenDungeonsNotOwner() public {
        string memory mapHash1 = "QmHash123";
        string memory dbUrl1 = "https://example.com/db1";
        string memory mapHash2 = "QmHash456";
        string memory dbUrl2 = "https://example.com/db2";
        uint256 dungeonId1 = 0;
        uint256 dungeonId2 = 1;

        // Create dungeons
        vm.startPrank(USER);
        dungeonMOW.createDungeon(mapHash1, dbUrl1);
        dungeonMOW.createDungeon(mapHash2, dbUrl2);
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
        vm.expectRevert(DungeonMOW.NotItemOwner.selector);
        dungeonMOW.moveItemBetweenDungeons(dungeonId1, dungeonId2, address(sword), swordId);
    }

    function testAddLinkedAssetIncorrectPayment() public {
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;
        uint256 charge = 0.5 ether;
        uint256 validityPeriod = 7200;

        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        vm.startPrank(NFT1_OWNER);
        dungeonMOW.setLinkingCharge(address(nft1), nft1Id, dungeonId, charge);
        dungeonMOW.signTerms(address(nft1), nft1Id, dungeonId, validityPeriod);
        vm.stopPrank();

        hoax(USER, charge);
        vm.expectRevert(DungeonMOW.IncorrectPaymentAmount.selector);
        dungeonMOW.addLinkedAsset{value: charge - 0.1 ether}(dungeonId, address(nft1), nft1Id);
    }

    function testMoveItemBetweenDungeons() public {
        string memory mapHash1 = "QmHash123";
        string memory dbUrl1 = "https://example.com/db1";
        string memory mapHash2 = "QmHash456";
        string memory dbUrl2 = "https://example.com/db2";
        uint256 dungeonId1 = 0;
        uint256 dungeonId2 = 1;

        // Create dungeons with correct parameters
        vm.startPrank(USER);
        dungeonMOW.createDungeon(mapHash1, dbUrl1);
        dungeonMOW.createDungeon(mapHash2, dbUrl2);
        vm.stopPrank();

        vm.startPrank(SWORD_OWNER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId1, address(sword), swordId);

        // Verify initial state
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(address(sword), swordId, dungeonId1), SWORD_OWNER);

        // Move sword between dungeons
        dungeonMOW.moveItemBetweenDungeons(dungeonId1, dungeonId2, address(sword), swordId);
        vm.stopPrank();

        // Verify:
        // 1. Dungeon contract still owns the NFT
        // 2. Management rights moved to new dungeon
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(address(sword), swordId, dungeonId1), address(0));
        assertEq(dungeonMOW.dungeonTokenOwners(address(sword), swordId, dungeonId2), SWORD_OWNER);
    }

    function testTransferDungeonOwnership() public {
        // Setup
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;

        // Create dungeon as USER
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        assertEq(dungeonMOW.ownerOf(dungeonId), USER);

        vm.prank(USER);
        dungeonMOW.transferFrom(USER, USER2, dungeonId);

        assertEq(dungeonMOW.ownerOf(dungeonId), USER2);
    }

    function testTransferDungeonOwnershipNotOwner() public {
        // Setup
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;

        // Create dungeon as USER
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        vm.prank(USER2);
        vm.expectRevert();
        dungeonMOW.transferFrom(USER2, USER, dungeonId);
    }

    function testTransferDungeonWithImportedItems() public {
        // Setup
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;

        // Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        vm.startPrank(SWORD_OWNER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId, address(sword), swordId);
        vm.stopPrank();

        vm.prank(USER);
        dungeonMOW.transferFrom(USER, USER2, dungeonId);

        assertEq(dungeonMOW.ownerOf(dungeonId), USER2);
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(address(sword), swordId, dungeonId), SWORD_OWNER);
    }
}
