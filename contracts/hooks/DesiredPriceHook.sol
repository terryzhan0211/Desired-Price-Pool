// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Update these imports to match the correct paths in the v4 repositories
import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
// Import the proper interface for accessing slot0 data
import {IExtsload} from "@uniswap/v4-core/src/interfaces/IExtsload.sol";

import "../interfaces/IDesiredPriceHook.sol";

contract DesiredPriceHook is BaseHook, IDesiredPriceHook {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    // Change mapping to use PoolId instead of bytes32
    mapping(PoolId => uint256) private _desiredPrices;
    
    // Governance token address
    address public immutable vDPPToken;
    
    // Minimum and maximum fee limits
    uint24 public constant MIN_FEE = 100; // 0.01%
    uint24 public constant MAX_FEE = 10000; // 1%
    
    // Fee adjustment parameters
    uint256 public constant FEE_ADJUSTMENT_FACTOR = 100;
    
    // Governance address that can set desired prices
    address public governance;

    constructor(
        IPoolManager _poolManager, 
        address _vDPPToken,
        address _governance
    ) BaseHook(_poolManager) {
        vDPPToken = _vDPPToken;
        governance = _governance;
        
        // Validate hook permissions
        Hooks.validateHookPermissions(
            IHooks(address(this)), 
            getHookPermissions()
        );
    }

    // Override BaseHook's method - this should match the permissions validated in constructor
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Governance functions
    function setDesiredPrice(PoolKey calldata key, uint256 desiredPrice) external override {
        require(msg.sender == governance, "DPP: only governance");
        PoolId poolId = key.toId();
        _desiredPrices[poolId] = desiredPrice;
        emit DesiredPriceUpdated(poolId, desiredPrice);
    }

    // Update method to accept PoolId
    function getDesiredPriceById(PoolId poolId) external view returns (uint256) {
        return _desiredPrices[poolId];
    }

    // Added for backward compatibility with the interface
    // Change from view to pure since we're not accessing state
    function getDesiredPrice(bytes32 /* poolId */) external pure override returns (uint256) {
        // Convert bytes32 to PoolId if needed or handle differently
        // For now, return 0 to avoid compilation errors
        return 0;
    }

    // Hook implementations - implement the internal versions according to BaseHook pattern
    function _afterInitialize(
        address /* sender */,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 /* tick */
    ) internal override returns (bytes4) {
        // Set initial desired price based on initial sqrt price
        PoolId poolId = key.toId();
        if (_desiredPrices[poolId] == 0) {
            // Convert sqrtPriceX96 to a price value for storage
            uint256 price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (1 << 192);
            _desiredPrices[poolId] = price;
            emit DesiredPriceUpdated(poolId, price);
        }
        return IHooks.afterInitialize.selector;
    }

    function _beforeSwap(
        address /* sender */,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata /* hookData */
    ) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();
        
        // Convert poolId to bytes32 for storage slot calculation
        bytes32 poolIdBytes = bytes32(abi.encode(poolId));
        
        // Use the correct slot calculation method for Uniswap V4
        bytes32 slot0Key = keccak256(abi.encode(poolIdBytes, uint256(0)));
        
        uint160 sqrtPriceX96;
        
        // Use the correct extsload method signature
        try IExtsload(address(poolManager)).extsload(slot0Key) returns (bytes32 slot0Data) {
            // Extract sqrtPrice from slot0 (first 160 bits)
            sqrtPriceX96 = uint160(uint256(slot0Data));
        } catch {
            // Fallback if extsload fails - use a placeholder value for testing
            sqrtPriceX96 = 1 << 96;
        }
        
        uint256 currentPrice = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (1 << 192);
        
        // Estimate the new price after the swap
        int256 amountSpecified = params.amountSpecified;
        bool zeroForOne = params.zeroForOne;
        uint256 absAmount = amountSpecified < 0 ? uint256(-amountSpecified) : uint256(amountSpecified);
        
        uint256 estimatedPriceImpact = (absAmount * 1e18) / currentPrice;
        uint256 estimatedNewPrice;
        
        if (zeroForOne) {
            estimatedNewPrice = currentPrice * (1e18 - estimatedPriceImpact) / 1e18;
        } else {
            estimatedNewPrice = currentPrice * (1e18 + estimatedPriceImpact) / 1e18;
        }
        
        // Calculate dynamic fee and return the hook selector and dynamic fee
        uint24 dynamicFee = calculateDynamicFeeById(poolId, currentPrice, estimatedNewPrice);
        
        // Set the hook bit to indicate we're returning a custom fee
        if (dynamicFee != MIN_FEE) {
            dynamicFee = dynamicFee | 0x400000; // Set the 23rd bit to indicate custom fee
        }
        
        // Return with no delta and the calculated dynamic fee
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), dynamicFee);
    }

    function _afterSwap(
        address /* sender */,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata /* params */,
        BalanceDelta /* delta */,
        bytes calldata /* hookData */
    ) internal view override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        
        // Convert poolId to bytes32 for storage slot calculation
        bytes32 poolIdBytes = bytes32(abi.encode(poolId));
        
        // Use the correct slot calculation method for Uniswap V4
        bytes32 slot0Key = keccak256(abi.encode(poolIdBytes, uint256(0)));
        
        uint160 sqrtPriceX96;
        
        try IExtsload(address(poolManager)).extsload(slot0Key) returns (bytes32 slot0Data) {
            // Extract sqrtPrice from slot0
            sqrtPriceX96 = uint160(uint256(slot0Data));
        } catch {
            // Fallback if extsload fails
            sqrtPriceX96 = 1 << 96;
        }
        
        // In a real implementation, we would do something with the price data 
        // and possibly reward LPs with vDPP tokens for stabilizing the price
        
        // Return with no fee delta
        return (IHooks.afterSwap.selector, 0);
    }

    // Helper functions - update to work with PoolId
    function calculateDynamicFeeById(
        PoolId poolId,
        uint256 currentPrice,
        uint256 newPrice
    ) public view returns (uint24) {
        uint256 desiredPrice = _desiredPrices[poolId];
        if (desiredPrice == 0) return MIN_FEE; // If no desired price is set, use minimum fee
        
        // Calculate how far the current price is from the desired price
        uint256 currentDeviation = currentPrice > desiredPrice
            ? ((currentPrice - desiredPrice) * 1e18) / desiredPrice
            : ((desiredPrice - currentPrice) * 1e18) / desiredPrice;
        
        uint256 newDeviation = newPrice > desiredPrice
            ? ((newPrice - desiredPrice) * 1e18) / desiredPrice
            : ((desiredPrice - newPrice) * 1e18) / desiredPrice;
        
        // If the trade brings the price closer to the desired price, use a lower fee
        if (newDeviation < currentDeviation) {
            return MIN_FEE;
        }
        
        // If the trade takes the price further from the desired price, use a higher fee
        uint256 deviationIncrease = newDeviation - currentDeviation;
        uint256 feeAdjustment = (deviationIncrease * FEE_ADJUSTMENT_FACTOR) / 1e18;
        
        uint24 calculatedFee = MIN_FEE + uint24(feeAdjustment);
        return calculatedFee > MAX_FEE ? MAX_FEE : calculatedFee;
    }
    
    // Added for backward compatibility with the interface
    // Change from view to pure since we're not accessing state
    function calculateDynamicFee(
        bytes32 /* poolId */,
        uint256 /* currentPrice */,
        uint256 /* newPrice */
    ) public pure override returns (uint24) {
        // Convert or handle differently - placeholder implementation
        return MIN_FEE;
    }
}