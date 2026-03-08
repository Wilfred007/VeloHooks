// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

interface ILoyaltyToken {
    function mint(address to, uint256 amount) external;
}

contract LoyaltyHook is IHooks {
    using PoolIdLibrary for PoolKey;

    IPoolManager public immutable manager;
    address public reactiveNetwork;
    address public loyaltyToken;
    uint256 public rewardMultiplier = 1;

    mapping(address => uint256) public points;
    mapping(address => uint256) public redeemedPoints;

    error NotManager();
    error NotReactiveNetwork();

    modifier onlyManager() {
        if (msg.sender != address(manager)) revert NotManager();
        _;
    }

    modifier onlyReactiveNetwork() {
        if (msg.sender != reactiveNetwork) revert NotReactiveNetwork();
        _;
    }

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    function setLoyaltyToken(address _loyaltyToken) external {
        // In a real scenario, this would be restricted to the owner
        loyaltyToken = _loyaltyToken;
    }

    function setReactiveNetwork(address _reactiveNetwork) external {
        reactiveNetwork = _reactiveNetwork;
    }

    function setMultiplier(uint256 _multiplier) external onlyReactiveNetwork {
        rewardMultiplier = _multiplier;
    }

    function getTierMultiplier(address user) public view returns (uint256) {
        uint256 userPoints = points[user];
        if (userPoints >= 10000) return 3; // Platinum Tier
        if (userPoints >= 5000) return 2; // Gold Tier
        return 1; // Base Tier
    }

    function redeemPoints(uint256 amount) external {
        require(points[msg.sender] >= amount, "Insufficient points");
        points[msg.sender] -= amount;
        redeemedPoints[msg.sender] += amount;

        if (loyaltyToken != address(0)) {
            ILoyaltyToken(loyaltyToken).mint(msg.sender, amount * 10 ** 18);
        }
    }

    function beforeInitialize(
        address,
        PoolKey calldata,
        uint160
    ) external pure override returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(
        address,
        PoolKey calldata,
        uint160,
        int24
    ) external pure override returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external override onlyManager returns (bytes4, BalanceDelta) {
        uint256 liquidity = uint256(params.liquidityDelta);
        uint256 tierBoost = getTierMultiplier(sender);
        points[sender] +=
            (liquidity / 1e18) *
            10 *
            rewardMultiplier *
            tierBoost;
        return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external override onlyManager returns (bytes4, BalanceDelta) {
        uint256 liquidity = uint256(-params.liquidityDelta);
        uint256 penalty = (liquidity / 1e18) * 10 * rewardMultiplier;

        if (points[sender] > penalty) {
            points[sender] -= penalty;
        } else {
            points[sender] = 0;
        }

        return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeSwap(
        address,
        PoolKey calldata,
        SwapParams calldata,
        bytes calldata
    ) external pure override returns (bytes4, BeforeSwapDelta, uint24) {
        return (
            IHooks.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            0
        );
    }

    function afterSwap(
        address sender,
        PoolKey calldata,
        SwapParams calldata params,
        BalanceDelta,
        bytes calldata
    ) external override onlyManager returns (bytes4, int128) {
        uint256 amount = params.amountSpecified < 0
            ? uint256(-params.amountSpecified)
            : uint256(params.amountSpecified);
        uint256 tierBoost = getTierMultiplier(sender);
        points[sender] += (amount / 1e18) * rewardMultiplier * tierBoost;
        return (IHooks.afterSwap.selector, 0);
    }

    function beforeDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.afterDonate.selector;
    }
}
