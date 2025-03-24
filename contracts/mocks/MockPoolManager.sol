// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

contract MockPoolManager {
    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 protocolFee;
        uint24 swapFee;
        bool unlocked;
        uint24 hookSwapFee;
        uint24 hookWithdrawFee;
    }
    
    mapping(bytes32 => Slot0) public slots;
    
    // Function to set slot0 data for testing
    function setSlot0(
        bytes32 poolId,
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 protocolFee,
        uint24 swapFee
    ) external {
        slots[poolId] = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            protocolFee: protocolFee,
            swapFee: swapFee,
            unlocked: true,
            hookSwapFee: 0,
            hookWithdrawFee: 0
        });
    }
    
    // Mock implementation of getSlot0
    function getSlot0(bytes32 poolId) 
        external 
        view 
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 protocolFee,
            uint24 swapFee,
            bool unlocked,
            uint24 hookSwapFee,
            uint24 hookWithdrawFee
        )
    {
        Slot0 memory slot = slots[poolId];
        return (
            slot.sqrtPriceX96,
            slot.tick,
            slot.protocolFee,
            slot.swapFee,
            slot.unlocked,
            slot.hookSwapFee,
            slot.hookWithdrawFee
        );
    }
}