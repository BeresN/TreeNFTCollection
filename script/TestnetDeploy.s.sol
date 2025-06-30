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
        TreeGrowthStages stages = new TreeGrowthStages(address(whitelist));

        

        console.log("Whitelist deployed at:", address(whitelist));
        console.log("CalculateStage deployed at:", address(stages));
        vm.stopBroadcast();

    }
}
