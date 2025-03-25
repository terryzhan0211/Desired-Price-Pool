// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IExtsload} from "@uniswap/v4-core/src/interfaces/IExtsload.sol";

/**
 * @title MockPoolManager
 * @dev A simplified mock of the Uniswap V4 PoolManager for testing purposes
 */
contract MockPoolManager is IExtsload {
    using PoolIdLibrary for PoolKey;
    
    // Storage for extsload mock
    mapping(bytes32 => bytes32) private _storage;
    
    constructor() {
        // Initialize with some default values for testing
        bytes32 defaultSlot = bytes32(uint256(1 << 96)); // Default sqrtPriceX96 = 2^96
        _storage[bytes32(0)] = defaultSlot;
    }
    
    // Set a value for extsload to return
    function setExtsloadValue(bytes32 slot, bytes32 value) external {
        _storage[slot] = value;
    }
    
    // Implement extsload for interface compatibility (IExtsload)
    function extsload(bytes32 slot) external view override returns (bytes32) {
        return _storage[slot];
    }
    
    // Implement extsload with multiple slots (IExtsload)
    function extsload(bytes32 startSlot, uint256 nSlots) external view override returns (bytes32[] memory values) {
        values = new bytes32[](nSlots);
        for (uint256 i = 0; i < nSlots; i++) {
            values[i] = _storage[bytes32(uint256(startSlot) + i)];
        }
        return values;
    }
    
    // Implement extsload with array of slots (IExtsload)
    function extsload(bytes32[] calldata slots) external view override returns (bytes32[] memory values) {
        values = new bytes32[](slots.length);
        for (uint256 i = 0; i < slots.length; i++) {
            values[i] = _storage[slots[i]];
        }
        return values;
    }

    // Mock minimal implementation needed for hook testing
    function initialize(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24) {
        // Convert the price to a tick approximation
        int24 tick = int24(int256(uint256(sqrtPriceX96) / 2**64));
        
        // Store sqrtPriceX96 in the pool's storage slot
        bytes32 poolId = PoolId.unwrap(key.toId());
        bytes32 slot0Key = keccak256(abi.encode(poolId, uint256(0)));
        _storage[slot0Key] = bytes32(uint256(sqrtPriceX96));
        
        return tick;
    }
}