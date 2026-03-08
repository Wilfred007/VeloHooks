// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILoyaltyHook {
    function setMultiplier(uint256 _multiplier) external;
}

contract ReactiveLoyalty {
    address public loyaltyHook;
    address public owner;

    event CrossChainMilestoneReached(string description, uint256 multiplier);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _loyaltyHook) {
        loyaltyHook = _loyaltyHook;
        owner = msg.sender;
    }

    function triggerMilestone(
        string calldata description,
        uint256 newMultiplier
    ) external onlyOwner {
        ILoyaltyHook(loyaltyHook).setMultiplier(newMultiplier);
        emit CrossChainMilestoneReached(description, newMultiplier);
    }
}
