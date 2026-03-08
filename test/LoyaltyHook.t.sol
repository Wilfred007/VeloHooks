// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {LoyaltyHook} from "../src/LoyaltyHook.sol";
import {LoyaltyToken} from "../src/LoyaltyToken.sol";
import {ReactiveLoyalty} from "../src/ReactiveLoyalty.sol";
import {Currency} from "v4-core/types/Currency.sol";

contract LoyaltyHookTest is Test {
    PoolManager manager;
    LoyaltyHook hook;
    ReactiveLoyalty reactive;
    PoolKey key;

    address alice = address(0x1);

    function setUp() public {
        manager = new PoolManager(address(this));
        hook = new LoyaltyHook(manager);
        reactive = new ReactiveLoyalty(address(hook));
        LoyaltyToken token = new LoyaltyToken(address(hook));
        hook.setLoyaltyToken(address(token));
        hook.setReactiveNetwork(address(reactive));

        // Mock PoolKey
        key = PoolKey({
            currency0: Currency.wrap(address(0x10)),
            currency1: Currency.wrap(address(0x11)),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
    }

    function test_points_on_swap() public {
        vm.prank(address(manager));
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

        assertEq(hook.points(alice), 10);
    }

    function test_points_on_liquidity() public {
        vm.prank(address(manager));
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

        // 100 ether / 1e18 * 10 = 1000 points
        assertEq(hook.points(alice), 1000);
    }

    function test_multiplier_boost() public {
        // Trigger multiplier update from Reactive contract
        vm.prank(address(this));
        reactive.triggerMilestone("High Volume on Polygon", 2);

        assertEq(hook.rewardMultiplier(), 2);

        vm.prank(address(manager));
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

        // 10 * 2 = 20 points
        assertEq(hook.points(alice), 20);
    }

    function test_withdrawal_penalty() public {
        vm.startPrank(address(manager));
        // Add 100 liquidity -> 1000 points
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
        assertEq(hook.points(alice), 1000);

        // Remove 50 liquidity -> -500 points
        hook.afterRemoveLiquidity(
            alice,
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: -50 ether,
                salt: 0
            }),
            BalanceDelta.wrap(0),
            BalanceDelta.wrap(0),
            ""
        );
        assertEq(hook.points(alice), 500);
        vm.stopPrank();
    }

    function test_tier_multiplier() public {
        // Alice starts with 0 points (Base Tier: 1x)
        vm.prank(address(manager));
        hook.afterSwap(
            alice,
            key,
            SwapParams(true, -10 ether, 0),
            BalanceDelta.wrap(0),
            ""
        );
        assertEq(hook.points(alice), 10);

        // Manually boost Alice to Gold Tier (5000+ points)
        // Note: For testing we can use a huge liquidity add
        vm.prank(address(manager));
        hook.afterAddLiquidity(
            alice,
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 500 ether, // 500 * 10 = 5000 points
                salt: 0
            }),
            BalanceDelta.wrap(0),
            BalanceDelta.wrap(0),
            ""
        );

        // Points: 10 + 5000 = 5010 (Gold Tier: 2x)
        assertEq(hook.getTierMultiplier(alice), 2);

        // Swap 10 ether -> 10 * 1 (multiplier) * 2 (tier) = 20 points
        vm.prank(address(manager));
        hook.afterSwap(
            alice,
            key,
            SwapParams(true, -10 ether, 0),
            BalanceDelta.wrap(0),
            ""
        );
        assertEq(hook.points(alice), 5030);
    }

    function test_redemption() public {
        // Give Alice 100 points
        vm.prank(address(manager));
        hook.afterSwap(
            alice,
            key,
            SwapParams(true, -100 ether, 0),
            BalanceDelta.wrap(0),
            ""
        );
        assertEq(hook.points(alice), 100);

        // Redeem 50 points
        vm.prank(alice);
        hook.redeemPoints(50);

        assertEq(hook.points(alice), 50);
        assertEq(hook.redeemedPoints(alice), 50);

        // Check token balance (50 * 10^18)
        address token = hook.loyaltyToken();
        assertEq(LoyaltyToken(token).balanceOf(alice), 50 * 10 ** 18);
    }

    function test_only_reactive_can_set_multiplier() public {
        vm.expectRevert(LoyaltyHook.NotReactiveNetwork.selector);
        hook.setMultiplier(5);
    }
}
