// SPDX-License-Identifier: GPL (MIT, with GPL code from apeswap to be moved to a separate library)

/*
Join us at PolyCrystal.Finance!
█▀▀█ █▀▀█ █░░ █░░█ █▀▀ █▀▀█ █░░█ █▀▀ ▀▀█▀▀ █▀▀█ █░░ 
█░░█ █░░█ █░░ █▄▄█ █░░ █▄▄▀ █▄▄█ ▀▀█ ░░█░░ █▄▄█ █░░ 
█▀▀▀ ▀▀▀▀ ▀▀▀ ▄▄▄█ ▀▀▀ ▀░▀▀ ▄▄▄█ ▀▀▀ ░░▀░░ ▀░░▀ ▀▀▀
*/

pragma solidity 0.6.12;

import "./BaseStrategy.sol";

abstract contract BaseStrategyApeLPSingle is BaseStrategy {
    using SafeERC20 for IERC20;
    
    function _vaultHarvest() internal virtual;

    function _compound() internal override whenNotPaused {
        // Harvest farm tokens
        _vaultHarvest();

        // Converts farm tokens into want tokens
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));
        if (earnedAmt == 0) return;
        
        earnedAmt = distributeFees(earnedAmt);
        earnedAmt = buyBack(earnedAmt);

        if (earnedAddress == token0Address) {
            // Swap half earned to token1
            _swap(
                earnedAmt / 2,
                earnedToToken1Path,
                address(this)
            );
        } else if (earnedAddress == token1Address) {
            // Swap half earned to token0
            _swap(
                earnedAmt / 2,
                earnedToToken0Path,
                address(this)
            );
        } else {
            // Pseudorandomly pick one to swap to first. Perfect distribution and unpredictability are unnecessary, we just don't want dust collecting
            uint tokenFirst = block.timestamp % 2;
            _swap(
            earnedAmt / 2,
            tokenFirst == 0 ? earnedToToken0Path : earnedToToken1Path,
            address(this)
            );
            //then swap the rest to the other
            _swap(
            IERC20(earnedAddress).balanceOf(address(this)),
            tokenFirst == 0 ? earnedToToken1Path : earnedToToken0Path,
            address(this)
            );
        }

        // Get want tokens, ie. add liquidity
        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
        uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
        if (token0Amt > 0 && token1Amt > 0) {
            //simplified routing
            (uint reserve0, uint reserve1) = ApeLibrary.getReserves(apeFactoryAddress, token0Address, token1Address);
    
            uint amount1Optimal = ApeLibrary.quote(token0Amt, reserve0, reserve1);
            if (amount1Optimal <= token1Amt) token1Amt = amount1Optimal;
            else token0Amt = ApeLibrary.quote(token1Amt, reserve1, reserve0);
            
    
            IERC20(token0Address).safeTransfer(wantAddress, token0Amt);
            IERC20(token1Address).safeTransfer(wantAddress, token1Amt);
            IApePair(wantAddress).mint(address(this));
        }

        lastEarnBlock = block.number;

        _farm();
    }
}
