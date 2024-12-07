// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Nft1} from "../src/sampleNfts/Nft1.sol";
import {Nft2} from "../src/sampleNfts/Nft2.sol";
import {Potion} from "../src/sampleNfts/Potion.sol";
import {Sword} from "../src/sampleNfts/Sword.sol";

contract DeploySampleNfts is Script {
    function run() external returns (Nft1, Nft2, Potion, Sword) {
        vm.startBroadcast();
        Nft1 nft1 = new Nft1();
        Nft2 nft2 = new Nft2();
        Potion potion = new Potion();
        Sword sword = new Sword();
        vm.stopBroadcast();
        return (nft1, nft2, potion, sword);
    }
}