// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployDungeonMOW} from "../../script/DeployDungeonMOW.s.sol";
import {DungeonMOW} from "../../src/Dungeon.sol";
import {Nft1} from "../../src/sampleNfts/Nft1.sol";
import {Nft2} from "../../src/sampleNfts/Nft2.sol";
import {Potion} from "../../src/sampleNfts/Potion.sol";
import {Sword} from "../../src/sampleNfts/Sword.sol";

contract DungeonIntegrationTest is Test {
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

    function testIntegrationCreateDungeonAndImportItems() public {
        // Setup
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;

        // 1. Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        // 2. Import sword
        vm.startPrank(SWORD_OWNER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId, address(sword), swordId);
        vm.stopPrank();

        // 3. Import potion
        vm.startPrank(POTION_OWNER);
        potion.approve(address(dungeonMOW), potionId);
        dungeonMOW.importItem(dungeonId, address(potion), potionId);
        vm.stopPrank();

        // Verify final state
        assertEq(dungeonMOW.ownerOf(dungeonId), USER);
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(potion.ownerOf(potionId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(address(sword), swordId, dungeonId), SWORD_OWNER);
        assertEq(dungeonMOW.dungeonTokenOwners(address(potion), potionId, dungeonId), POTION_OWNER);
    }

    function testIntegrationLinkNFTWithPayment() public {
        // Setup
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;
        uint256 charge = 0.5 ether;
        uint256 validityPeriod = 7200;

        // 1. Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        // 2. NFT owner sets up linking terms
        vm.startPrank(NFT1_OWNER);
        dungeonMOW.setLinkingCharge(address(nft1), nft1Id, dungeonId, charge);
        dungeonMOW.signTerms(address(nft1), nft1Id, dungeonId, validityPeriod);
        vm.stopPrank();

        // Record initial balance
        uint256 initialBalance = NFT1_OWNER.balance;

        // 3. Dungeon owner adds linked asset with payment
        vm.deal(USER, charge);
        vm.prank(USER);
        dungeonMOW.addLinkedAsset{value: charge}(dungeonId, address(nft1), nft1Id);

        // Verify final state
        assertEq(NFT1_OWNER.balance, initialBalance + charge);
        assertTrue(dungeonMOW.isNFTLinked(dungeonId, address(nft1), nft1Id));
    }

    function testIntegrationTransferDungeonWithAssetsAndLinks() public {
        // Setup
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;
        uint256 charge = 0.5 ether;
        uint256 validityPeriod = 7200;

        // 1. Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        // 2. Import sword
        vm.startPrank(SWORD_OWNER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId, address(sword), swordId);
        vm.stopPrank();

        // 3. Setup and add linked NFT
        vm.startPrank(NFT1_OWNER);
        dungeonMOW.setLinkingCharge(address(nft1), nft1Id, dungeonId, charge);
        dungeonMOW.signTerms(address(nft1), nft1Id, dungeonId, validityPeriod);
        vm.stopPrank();

        vm.deal(USER, charge);
        vm.prank(USER);
        dungeonMOW.addLinkedAsset{value: charge}(dungeonId, address(nft1), nft1Id);

        // 4. Transfer dungeon ownership
        vm.prank(USER);
        dungeonMOW.transferFrom(USER, USER2, dungeonId);

        // Verify final state
        assertEq(dungeonMOW.ownerOf(dungeonId), USER2);
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(address(sword), swordId, dungeonId), SWORD_OWNER);
        assertTrue(dungeonMOW.isNFTLinked(dungeonId, address(nft1), nft1Id));
    }

    function testIntegrationListAndPurchaseDungeonWithAssets() public {
        // Setup
        string memory mapHash = "QmHash123";
        string memory dbUrl = "https://example.com/db";
        uint256 dungeonId = 0;
        uint256 price = 1 ether;

        // 1. Create dungeon
        vm.prank(USER);
        dungeonMOW.createDungeon(mapHash, dbUrl);

        // 2. Import sword
        vm.startPrank(SWORD_OWNER);
        sword.approve(address(dungeonMOW), swordId);
        dungeonMOW.importItem(dungeonId, address(sword), swordId);
        vm.stopPrank();

        // 3. List dungeon for sale
        vm.prank(USER);
        dungeonMOW.listDungeonForSale(dungeonId, price);

        // Record initial balances
        uint256 initialSellerBalance = USER.balance;

        // 4. Purchase dungeon
        vm.deal(USER2, price);
        vm.prank(USER2);
        dungeonMOW.purchaseDungeon{value: price}(dungeonId);

        // Verify final state
        assertEq(dungeonMOW.ownerOf(dungeonId), USER2);
        assertEq(USER.balance, initialSellerBalance + price);
        assertEq(dungeonMOW.getDungeonListingPrice(dungeonId), 0);
        assertEq(sword.ownerOf(swordId), address(dungeonMOW));
        assertEq(dungeonMOW.dungeonTokenOwners(address(sword), swordId, dungeonId), SWORD_OWNER);
    }
}