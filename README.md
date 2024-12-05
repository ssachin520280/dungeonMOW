# Dungeon

This project implements a blockchain-based dungeon game system. It uses Foundry and OpenZeppelin contracts. At its core, it's built around the DungeonMOW contract. You can find it in [src/Dungeon.sol](src/Dungeon.sol). This contract allows players to create, own, and manage dungeons as NFTs.

The system features a unique linking mechanism. Players can import other NFTs, like swords, potions, or character items, into their dungeons. It has a sophisticated permission system. This system maintains original ownership while allowing dungeon integration.

The contract implements ERC721 standards. It includes features for setting linking charges. It also manages terms of use and transfers dungeon ownership.