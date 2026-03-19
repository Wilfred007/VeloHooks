// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {LoyaltyHook} from "../src/LoyaltyHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract HookMiner is Script {
    function run() external pure {
        address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        address poolManager = 0x9e512795Be621572Ef073bc4d395554F71334D8a;
        bytes memory bytecode = abi.encodePacked(type(LoyaltyHook).creationCode, abi.encode(poolManager)); 
        
        uint160 mask = 0x3FF0; 
        
        uint256 salt = 0;
        while (true) {
            bytes32 saltBytes = bytes32(salt);
            address predicted = predictAddress(factory, saltBytes, keccak256(bytecode));
            if ((uint160(predicted) & 0x3FFF) == mask) {
                console.log("Found salt:", salt);
                console.log("Predicted address:", predicted);
                break;
            }
            salt++;
            if (salt > 100000) {
                console.log("Giving up after 100k iterations");
                break;
            }
        }
    }

    function predictAddress(address factory, bytes32 salt, bytes32 bytecodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), factory, salt, bytecodeHash)))));
    }
}

contract LoyaltyHookMock {} // Just for bytecode size/hash simulation
