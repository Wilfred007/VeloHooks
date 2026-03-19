// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

contract FaucetScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address faucet = 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434;

        vm.startBroadcast(deployerPrivateKey);
        (bool success, ) = faucet.call{value: 0.04 ether}("");
        require(success, "Transfer failed");
        vm.stopBroadcast();
    }
}
