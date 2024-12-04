// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {ERC721URIStorage} from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {console} from "../lib/forge-std/src/console.sol";

// At the top of the contract, add custom errors
error NotDungeonOwner();
error NFTDoesNotExist();
error DungeonDoesNotExist();
error NotItemOwner();
error TermsNotSigned();
error TermsExpired();
error IncorrectPaymentAmount();

contract DungeonMOW is ERC721URIStorage {
    struct LinkedAsset {
        address nftContract; // Address of the NFT contract
        uint256 tokenId;     // ID of the NFT
        bool usageGranted;   // Whether usage rights have been granted
    }

    struct Dungeon {
        uint256 id;
        address owner;
        string metadataURI; // Points to metadata storage
    }

    uint256 private _nextTokenId;
    mapping(uint256 => Dungeon) private _dungeons;

    // New mapping to store linked assets for each dungeon
    mapping(uint256 => LinkedAsset[]) private _dungeonLinkedAssets;

    // Mapping to track imported movable NFTs for each dungeon
    mapping(uint256 => mapping(address => mapping(uint256 => address))) public dungeonTokenOwners;

    // Add a mapping to store the linking charge set by each NFT owner for each dungeon
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public nftLinkingCharges;

    // Add a mapping to store signed terms by NFT owners for each dungeon
    mapping(address => mapping(uint256 => mapping(uint256 => bytes32))) public nftTermsHashes;

    // Add a mapping to store the timestamp when terms were signed
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public nftTermsTimestamps;

    // Add a mapping to store the validity period set by each NFT owner for each dungeon
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public nftTermsValidity;

    event DungeonCreated(
        uint256 indexed id,
        address indexed owner,
        string metadataURI
    );

    event LinkedAssetAdded(
        uint256 indexed dungeonId,
        address indexed nftContract,
        uint256 indexed tokenId
    );

    event ItemImported(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed player
    );

    event ItemExported(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed player
    );

    event ItemMovedBetweenDungeons(
        uint256 indexed fromDungeonId,
        uint256 indexed toDungeonId,
        address indexed nftContract,
        uint256 tokenId,
        address player
    );

    constructor() ERC721("DungeonMOW", "DGM") {}

    /**
     * @dev Create a new dungeon MOW.
     * @param metadataURI URI pointing to metadata (e.g., IPFS/Arweave).
     */
    function createDungeon(string memory metadataURI) external {
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, metadataURI);

        _dungeons[tokenId] = Dungeon({
            id: tokenId,
            owner: msg.sender,
            metadataURI: metadataURI
        });

        emit DungeonCreated(tokenId, msg.sender, metadataURI);
    }

    /**
     * @dev Add a fixed linked NFT asset to the dungeon map.
     * @param dungeonId ID of the dungeon map.
     * @param nftContract Address of the NFT contract.
     * @param tokenId ID of the linked NFT.
     */
    function addLinkedAsset(
        uint256 dungeonId,
        address nftContract,
        uint256 tokenId
    ) external payable {
        if (ownerOf(dungeonId) != msg.sender) revert NotDungeonOwner();

        IERC721 nft = IERC721(nftContract);
        address itemOwner = nft.ownerOf(tokenId);
        if (itemOwner == address(0)) revert NFTDoesNotExist();

        // Check if terms are signed and valid
        bytes32 storedHash = nftTermsHashes[nftContract][tokenId][dungeonId];
        uint256 signedTimestamp = nftTermsTimestamps[nftContract][tokenId][dungeonId];
        uint256 validityPeriod = nftTermsValidity[nftContract][tokenId][dungeonId];
        if (storedHash == bytes32(0)) revert TermsNotSigned();
        if (block.timestamp > signedTimestamp + validityPeriod) revert TermsExpired();

        // Ensure payment matches the charge set by the NFT owner
        uint256 charge = nftLinkingCharges[nftContract][tokenId][dungeonId];
        if (msg.value != charge) revert IncorrectPaymentAmount();
        payable(itemOwner).transfer(msg.value);

        // Store the linked asset in the new mapping
        _dungeonLinkedAssets[dungeonId].push(LinkedAsset({
            nftContract: nftContract,
            tokenId: tokenId,
            usageGranted: true
        }));

        emit LinkedAssetAdded(dungeonId, nftContract, tokenId);
    }

    /**
     * @dev Import a movable NFT to a specific dungeon.
     * @param dungeonId ID of the dungeon map.
     * @param nftContract Address of the NFT contract.
     * @param tokenId ID of the NFT to import.
     */
    function importItem(uint256 dungeonId, address nftContract, uint256 tokenId) public {
        if (ownerOf(dungeonId) != msg.sender) revert NotDungeonOwner();
        
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        dungeonTokenOwners[dungeonId][nftContract][tokenId] = msg.sender;
        emit ItemImported(nftContract, tokenId, msg.sender);
    }

    /**
     * @dev Export a movable NFT from a specific dungeon.
     * @param dungeonId ID of the dungeon map.
     * @param nftContract Address of the NFT contract.
     * @param tokenId ID of the NFT to export.
     */
    function exportItem(uint256 dungeonId, address nftContract, uint256 tokenId) public {
        if (dungeonTokenOwners[dungeonId][nftContract][tokenId] != msg.sender) revert NotItemOwner();
        
        delete dungeonTokenOwners[dungeonId][nftContract][tokenId]; // Clear ownership before transfer
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        emit ItemExported(nftContract, tokenId, msg.sender);
    }

    /**
     * @dev Get Dungeon details.
     * @param dungeonId ID of the dungeon map.
     */
    function getDungeon(uint256 dungeonId) external view returns (Dungeon memory) {
        if (ownerOf(dungeonId) == address(0)) revert DungeonDoesNotExist();
        return _dungeons[dungeonId];
    }

    /**
     * @dev Move a movable NFT from one dungeon to another.
     * @param fromDungeonId ID of the source dungeon.
     * @param toDungeonId ID of the destination dungeon.
     * @param nftContract Address of the NFT contract.
     * @param tokenId ID of the NFT to move.
     */
    function moveItemBetweenDungeons(
        uint256 fromDungeonId,
        uint256 toDungeonId,
        address nftContract,
        uint256 tokenId
    ) external {
        if (dungeonTokenOwners[fromDungeonId][nftContract][tokenId] != msg.sender) revert NotItemOwner();
        if (ownerOf(toDungeonId) != msg.sender) revert NotDungeonOwner();

        // Remove the NFT from the source dungeon
        delete dungeonTokenOwners[fromDungeonId][nftContract][tokenId];

        // Add the NFT to the destination dungeon
        dungeonTokenOwners[toDungeonId][nftContract][tokenId] = msg.sender;

        emit ItemMovedBetweenDungeons(fromDungeonId, toDungeonId, nftContract, tokenId, msg.sender);
    }

    // Function for NFT owners to set the linking charge for a specific dungeon
    function setLinkingCharge(
        address nftContract,
        uint256 tokenId,
        uint256 dungeonId,
        uint256 charge
    ) external {
        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotItemOwner();
        nftLinkingCharges[nftContract][tokenId][dungeonId] = charge;
    }

    // Function for NFT owners to sign terms for a specific dungeon with a custom validity period
    function signTerms(
        address nftContract,
        uint256 tokenId,
        uint256 dungeonId,
        uint256 validityPeriod // in seconds
    ) external {
        console.log("entered");
        console.log("dhgfhg");
        IERC721 nft = IERC721(nftContract);
        console.log(nft.ownerOf(tokenId));
        if (nft.ownerOf(tokenId) != msg.sender) revert NotItemOwner();
        console.log("entered 227");

        // Generate the terms string
        string memory terms = string(abi.encodePacked(
            "I, the owner of NFT at contract address ", nftContract, 
            ", hereby grant permission to the owner of Dungeon NFT with ID ", dungeonId,
            ", to display my NFT within their dungeon. In exchange, the dungeon owner agrees to pay me ",
            nftLinkingCharges[nftContract][tokenId][dungeonId], 
            " wei. This agreement is valid until ", validityPeriod, 
            " seconds from the time of signing."
        ));

        // Store the hash of the terms, the timestamp, and the validity period
        bytes32 termsHash = keccak256(abi.encodePacked(terms));
        nftTermsHashes[nftContract][tokenId][dungeonId] = termsHash;
        nftTermsTimestamps[nftContract][tokenId][dungeonId] = block.timestamp;
        nftTermsValidity[nftContract][tokenId][dungeonId] = validityPeriod;

        // Console logs
        console.log("Terms signed for NFT contract: %s", nftContract);
    }
}