// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IDesiredPriceHook {
    /// @notice Emitted when the desired price is updated
    event DesiredPriceUpdated(bytes32 indexed poolId, uint256 newDesiredPrice);
    
    /// @notice Sets the desired price for a specific pool
    /// @param key The pool key
    /// @param desiredPrice The new desired price
    function setDesiredPrice(PoolKey calldata key, uint256 desiredPrice) external;
    
    /// @notice Gets the desired price for a specific pool
    /// @param poolId The pool identifier
    /// @return The desired price
    function getDesiredPrice(bytes32 poolId) external view returns (uint256);
    
    /// @notice Calculates the dynamic fee based on price impact
    /// @param poolId The pool identifier
    /// @param currentPrice The current pool price
    /// @param newPrice The price after the trade
    /// @return The calculated fee
    function calculateDynamicFee(bytes32 poolId, uint256 currentPrice, uint256 newPrice) external view returns (uint24);
}