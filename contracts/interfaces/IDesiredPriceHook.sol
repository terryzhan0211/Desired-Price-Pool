// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IDesiredPriceHook {
    // Event emitted when a pool's desired price is updated
    event DesiredPriceUpdated(PoolId indexed poolId, uint256 desiredPrice);
    
    /**
     * @notice Sets the desired price for a specific pool
     * @param key The pool key for the pool
     * @param desiredPrice The desired price for the pool
     */
    function setDesiredPrice(PoolKey calldata key, uint256 desiredPrice) external;
    
    /**
     * @notice Gets the current desired price for a pool
     * @param poolId The pool identifier
     * @return The desired price for the pool
     */
    function getDesiredPrice(bytes32 poolId) external view returns (uint256);
    
    /**
     * @notice Calculates a dynamic fee based on price movement relative to desired price
     * @param poolId The pool identifier
     * @param currentPrice The current price of the pool
     * @param newPrice The estimated new price after a trade
     * @return The calculated dynamic fee
     */
    function calculateDynamicFee(
        bytes32 poolId,
        uint256 currentPrice,
        uint256 newPrice
    ) external view returns (uint24);
}