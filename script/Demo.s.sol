// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LoyaltyHook} from "../src/LoyaltyHook.sol";
import {LoyaltyToken} from "../src/LoyaltyToken.sol";
import {ReactiveLoyalty} from "../src/ReactiveLoyalty.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";

// Mock PoolManager for local simulation
contract MockPoolManager {
    function getHook() external pure returns (address) {
        return address(0);
    }
}

contract DemoInteraction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("UNICHAIN_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address alice = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Setup - Using a local deployment simulation
        IPoolManager manager = IPoolManager(address(new MockPoolManager()));
        LoyaltyHook hook = new LoyaltyHook(manager);
        LoyaltyToken token = new LoyaltyToken(address(hook));
        ReactiveLoyalty reactive = new ReactiveLoyalty(address(hook));

        hook.setLoyaltyToken(address(token));
        hook.setReactiveNetwork(address(reactive));

        console.log("--- VeloHooks Demo Started ---");
        console.log("Alice Address:", alice);

        // Mock PoolKey for callback simulation
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0x10)),
            currency1: Currency.wrap(address(0x11)),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });

        // 2. Add Liquidity Simulation (Awards 10x points)
        // Simulate PoolManager calling afterAddLiquidity
        vm.stopBroadcast();
        vm.startPrank(address(manager));
        
        hook.afterAddLiquidity(
            alice,
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100 ether,
                salt: 0
            }),
            BalanceDelta.wrap(0),
            BalanceDelta.wrap(0),
            ""
        );
        console.log("1. Alice added 100 liquidity");
        console.log("   Points accrued:", hook.points(alice));

        // 3. Swap Simulation (Awards 1x points)
        hook.afterSwap(
            alice,
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -10 ether,
                sqrtPriceLimitX96: 0
            }),
            BalanceDelta.wrap(0),
            ""
        );
        console.log("2. Alice performed a 10 ETH swap");
        console.log("   Total points:", hook.points(alice));

        // 4. Milestone Trigger via Reactive Network (Boosts to 2x)
        vm.stopPrank();
        vm.startBroadcast(deployerPrivateKey);
        
        reactive.triggerMilestone("Protocol Peak Volume Reached!", 2);
        console.log("3. Reactive Milestone Triggered: 2x Reward Multiplier active!");

        // 5. Swap with Boost
        vm.stopBroadcast();
        vm.startPrank(address(manager));
        
        hook.afterSwap(
            alice,
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -10 ether,
                sqrtPriceLimitX96: 0
            }),
            BalanceDelta.wrap(0),
            ""
        );
        console.log("4. Alice performed another 10 ETH swap (Boosted)");
        console.log("   Total points:", hook.points(alice), "(Earned 20 points this time)");

        // 6. Tier Progression (Manual boost for demo)
        // Alice needs 5000 points for Gold Tier (2x boost)
        hook.afterAddLiquidity(
            alice,
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 400 ether,
                salt: 0
            }),
            BalanceDelta.wrap(0),
            BalanceDelta.wrap(0),
            ""
        );
        console.log("5. Alice added 400 more liquidity -> Reached Gold Tier (2x per-user boost)!");
        console.log("   Current Tier Multiplier:", hook.getTierMultiplier(alice));

        // 7. Swap with Tier Boost (Effective 4x: 2x Global * 2x Tier)
        hook.afterSwap(
            alice,
            key,
            SwapParams(true, -10 ether, 0),
            BalanceDelta.wrap(0),
            ""
        );
        console.log("6. Alice swapped again with Gold Tier + 2x Milestone");
        console.log("   Total points:", hook.points(alice), "(Earned 40 points this time)");

        // 8. Redemption Simulation
        vm.stopPrank();
        vm.startBroadcast(alice);
        
        uint256 pointsToRedeem = 50;
        hook.redeemPoints(pointsToRedeem);
        console.log("7. Alice redeemed 50 points for LTK tokens");
        console.log("   Current points balance:", hook.points(alice));
        console.log("   LTK Token Balance:", token.balanceOf(alice) / 1e18);

        vm.stopBroadcast();
        console.log("--- Demo Completed Successfully ---");
    }
}
