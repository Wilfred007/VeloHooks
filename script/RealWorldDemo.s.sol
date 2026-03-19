// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LoyaltyHook} from "../src/LoyaltyHook.sol";
import {LoyaltyToken} from "../src/LoyaltyToken.sol";
import {ReactiveLoyalty} from "../src/ReactiveLoyalty.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

// Mock Token for on-chain testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol, decimals) {}
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Helper contract to handle Uniswap v4's unlock mechanism
contract InteractionHelper is IUnlockCallback {
    IPoolManager public immutable manager;

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        (address sender, PoolKey memory key, uint256 action) = abi.decode(data, (address, PoolKey, uint256));
        
        if (action == 1) { // Add Liquidity
            (BalanceDelta delta, ) = manager.modifyLiquidity(
                key, 
                ModifyLiquidityParams({
                    tickLower: -60,
                    tickUpper: 60,
                    liquidityDelta: 1000 ether,
                    salt: 0
                }), 
                ""
            );
            // Settle balances based on actual delta
            if (delta.amount0() < 0) _settle(key.currency0, uint128(-delta.amount0()));
            if (delta.amount1() < 0) _settle(key.currency1, uint128(-delta.amount1()));
        } else if (action == 2) { // Swap 0 -> 1
            BalanceDelta delta = manager.swap(
                key,
                SwapParams({
                    zeroForOne: true,
                    amountSpecified: -100 ether,
                    sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
                }),
                ""
            );
            if (delta.amount0() < 0) _settle(key.currency0, uint128(-delta.amount0()));
            if (delta.amount1() > 0) manager.take(key.currency1, sender, uint128(delta.amount1()));
        } else if (action == 3) { // Swap 1 -> 0
            BalanceDelta delta = manager.swap(
                key,
                SwapParams({
                    zeroForOne: false,
                    amountSpecified: -100 ether,
                    sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
                }),
                ""
            );
            if (delta.amount1() < 0) _settle(key.currency1, uint128(-delta.amount1()));
            if (delta.amount0() > 0) manager.take(key.currency0, sender, uint128(delta.amount0()));
        }
        return "";
    }

    function performAction(bytes calldata data) external {
        manager.unlock(data);
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (currency.isAddressZero()) {
            manager.settle{value: amount}();
        } else {
            manager.sync(currency);
            MockERC20(Currency.unwrap(currency)).transfer(address(manager), amount);
            manager.settle();
        }
    }
}

contract RealWorldDemo is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("UNICHAIN_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PoolManager
        PoolManager manager = new PoolManager(deployer);
        console.log("PoolManager deployed to:", address(manager));

        // 2. Deploy Mock Tokens
        MockERC20 token0 = new MockERC20("Token 0", "TK0", 18);
        MockERC20 token1 = new MockERC20("Token 1", "TK1", 18);
        token0.mint(deployer, 1000 ether);
        token1.mint(deployer, 1000 ether);
        
        // Sort currencies
        Currency currency0 = Currency.wrap(address(token0) < address(token1) ? address(token0) : address(token1));
        Currency currency1 = Currency.wrap(address(token0) < address(token1) ? address(token1) : address(token0));

        // 3. Dynamic Salt Mining for LoyaltyHook
        // Uniswap v2 hooks need specific flags set in the address.
        // For LoyaltyHook, we need 0x3FF0 (all flags implemented).
        console.log("Mining valid hook salt... (this may take a few seconds)");
        
        bytes memory creationCode = abi.encodePacked(type(LoyaltyHook).creationCode, abi.encode(address(manager)));
        bytes32 bytecodeHash = keccak256(creationCode);
        
        uint256 salt;
        address hookAddress;
        uint160 mask = 0x3FF0;
        
        for (salt = 0; salt < 100000; salt++) {
            hookAddress = _predictAddress(salt, bytecodeHash);
            if ((uint160(hookAddress) & 0x3FFF) == mask) {
                break;
            }
        }
        
        require((uint160(hookAddress) & 0x3FFF) == mask, "Failed to mine salt");
        console.log("Found salt:", salt);

        LoyaltyHook hook = new LoyaltyHook{salt: bytes32(salt)}(manager);
        console.log("LoyaltyHook deployed to:", address(hook));

        // 4. Setup Hook Links
        LoyaltyToken ltk = new LoyaltyToken(address(hook));
        ReactiveLoyalty reactive = new ReactiveLoyalty(address(hook));
        hook.setLoyaltyToken(address(ltk));
        hook.setReactiveNetwork(address(reactive));

        // 5. Initialize Pool
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        manager.initialize(key, TickMath.getSqrtPriceAtTick(0)); 
        console.log("Pool initialized!");

        // 6. Interaction Helper (to handle unlock callbacks)
        InteractionHelper helper = new InteractionHelper(manager);
        token0.approve(address(helper), type(uint256).max);
        token1.approve(address(helper), type(uint256).max);

        token0.mint(address(helper), 10000 ether);
        token1.mint(address(helper), 10000 ether);

        console.log("--- Real-World Interactions ---");

        // Action 1: Add Liquidity
        helper.performAction(abi.encode(deployer, key, uint256(1)));
        console.log("1. Add Liquidity Transaction Confirmed!");
        console.log("   Helper Points:", hook.points(address(helper)));

        // Action 2: Perform Swap (0 -> 1)
        helper.performAction(abi.encode(deployer, key, uint256(2)));
        console.log("2. Swap (0 -> 1) Transaction Confirmed!");
        console.log("   Helper Points:", hook.points(address(helper)));

        // Action 3: Trigger Milestone
        reactive.triggerMilestone("Anvil Peak Volume!", 2);
        console.log("3. Milestone Transaction Confirmed (2x Multiplier)!");

        // Action 4: Swap (1 -> 0) with Boost
        helper.performAction(abi.encode(deployer, key, uint256(3)));
        console.log("4. Boosted Swap (1 -> 0) Transaction Confirmed!");
        console.log("   Total Final Points:", hook.points(address(helper)));

        vm.stopBroadcast();
        console.log("--- Real-World Demo Completed Successfully ---");
    }

    function _predictAddress(uint256 salt, bytes32 bytecodeHash) internal view returns (address) {
        // Standard Foundry salt deployment address prediction
        // Factory is 0x4e59b44847b379578588920cA78FbF26c0B4956C
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(0x4e59b44847b379578588920cA78FbF26c0B4956C),
            bytes32(salt),
            bytecodeHash
        )))));
    }
}
