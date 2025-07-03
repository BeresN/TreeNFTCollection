// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import "../src/CalculateStage.sol";
import "../src/TreeNFTCollection.sol";
import "../src/Whitelist.sol";


contract DeployScript is Script {


    function run() public {
        vm.startBroadcast();

        Whitelist whitelist = new Whitelist(5);
        TreeGrowthStages stages = new TreeGrowthStages(0x4D57E383C0c531BE6249afCe5C5A1390EE67Ca71);

        

        console.log("Whitelist deployed at:", address(whitelist));
        console.log("CalculateStage deployed at:", address(stages));
        vm.stopBroadcast();

    }
}
