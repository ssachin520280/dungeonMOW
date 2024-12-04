// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {DungeonMOW} from "../src/Dungeon.sol";

contract DeployDungeonMOW is Script {
    function run() external returns (DungeonMOW) {
        vm.startBroadcast();
        DungeonMOW dungeonMOW = new DungeonMOW();
        vm.stopBroadcast();
        return dungeonMOW;
    }
} 