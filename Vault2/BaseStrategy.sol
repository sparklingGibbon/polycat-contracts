// SPDX-License-Identifier: MIT

/*
Join us at PolyCrystal.Finance!
█▀▀█ █▀▀█ █░░ █░░█ █▀▀ █▀▀█ █░░█ █▀▀ ▀▀█▀▀ █▀▀█ █░░ 
█░░█ █░░█ █░░ █▄▄█ █░░ █▄▄▀ █▄▄█ ▀▀█ ░░█░░ █▄▄█ █░░ 
█▀▀▀ ▀▀▀▀ ▀▀▀ ▄▄▄█ ▀▀▀ ▀░▀▀ ▄▄▄█ ▀▀▀ ░░▀░░ ▀░░▀ ▀▀▀
*/


pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IApePair.sol";
import { ApeLibrary } from "./libraries/ApeLibrary.sol";
import "./libraries/GibbonRouter.sol";

abstract contract BaseStrategy is Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public wantAddress;
    address public token0Address;
    address public token1Address;
    address public earnedAddress;
    
    address public apeFactoryAddress = 0xCf083Be4164828f00cAE704EC15a36D711491284;
    address public constant crystlAddress = 0x76bF0C28e604CC3fE9967c83b3C3F31c213cfE64;
    address public constant rewardAddress = 0x917FB15E8aAA12264DCBdC15AFef7cD3cE76BA39; //UPDATE
    address public constant withdrawFeeAddress = 0x4879712c5D1A98C0B88Fb700daFF5c65d12Fd729; //UPDATE
    address public constant feeAddress = 0x1cb757f1eB92F25A917CE9a92ED88c1aC0734334; //UPDATE
    address public vaultHealerAddress;
    address public govAddress;

    uint256 public lastEarnBlock = block.number;
    uint256 public sharesTotal = 0;

    address public constant buyBackAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 public controllerFee = 0;
    uint256 public buyBackRate = 200;
    uint256 public constant feeMaxTotal = 500;
    uint256 public constant feeMax = 10000; // 100 = 1%

    uint256 public withdrawFeeFactor = 10; // 0.10% withdraw fee
    uint256 public constant withdrawFeeFactorMax = 500;

    address[] public earnedToWmaticPath;
    address[] public earnedToUsdcPath;
    address[] public earnedToCrystlPath;
    address[] public earnedToToken0Path;
    address[] public earnedToToken1Path;
    address[] public token0ToEarnedPath;
    address[] public token1ToEarnedPath;
    
    event SetSettings(
        uint256 _controllerFee,
        uint256 _buyBackRate,
        uint256 _withdrawFeeFactor
    );
    
    modifier onlyGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    function _vaultDeposit(uint256 _amount) internal virtual;
    function _vaultWithdraw(uint256 _amount) internal virtual;
    function vaultSharesTotal() public virtual view returns (uint256);
    function wantLockedTotal() public virtual view returns (uint256);
    function _resetAllowances() internal virtual;
    function _emergencyVaultWithdraw() internal virtual;
    function earn() internal virtual;
    
    function deposit(address _userAddress, uint256 _wantAmt) external onlyOwner whenNotPaused returns (uint256) {
        // Call must happen before transfer
        uint256 wantLockedBefore = wantLockedTotal();

        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        // Proper deposit amount for tokens with fees, or vaults with deposit fees
        uint256 sharesAdded = _farm();
        if (sharesTotal > 0) {
            sharesAdded = sharesAdded.mul(sharesTotal).div(wantLockedBefore);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        return sharesAdded;
    }

    function _farm() internal returns (uint256) {
        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (wantAmt == 0) return 0;
        
        uint256 sharesBefore = vaultSharesTotal();
        _vaultDeposit(wantAmt);
        uint256 sharesAfter = vaultSharesTotal();
        
        return sharesAfter.sub(sharesBefore);
    }

    function withdraw(address _userAddress, uint256 _wantAmt) external onlyOwner returns (uint256) {
        
        require(_wantAmt > 0, "_wantAmt is 0");
        
        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        
        // Check if strategy has tokens from panic
        if (_wantAmt > wantAmt) {
            _vaultWithdraw(_wantAmt.sub(wantAmt));
            wantAmt = IERC20(wantAddress).balanceOf(address(this));
        }

        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (_wantAmt > wantLockedTotal()) {
            _wantAmt = wantLockedTotal();
        }

        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal());
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);
        
        // Withdraw fee
        uint256 withdrawFee = _wantAmt
            .mul(withdrawFeeFactor)
            / 10000;
        if (withdrawFee > 0) {
            IERC20(wantAddress).safeTransfer(withdrawFeeAddress, withdrawFee);
        }
        
        _wantAmt = _wantAmt.sub(withdrawFee);

        IERC20(wantAddress).safeTransfer(vaultHealerAddress, _wantAmt);

        return sharesRemoved;
    }

    // To pay for earn function
    function distributeFees(uint256 _earnedAmt) internal returns (uint256) {
        
        if (_earnedAmt == 0) return 0;
        
        if (controllerFee > 0) {
            uint256 fee = _earnedAmt.mul(controllerFee)/feeMax;
    
            GibbonRouter._swap(
                fee,
                earnedToWmaticPath,
                feeAddress
            );
            
            _earnedAmt = _earnedAmt.sub(fee);
        }

        return _earnedAmt;
    }

    function buyBack(uint256 _earnedAmt) internal virtual returns (uint256) {
        
        if (_earnedAmt == 0) return 0;
        
        if (buyBackRate > 0) {
            uint256 buyBackAmt = _earnedAmt.mul(buyBackRate)/feeMax;
    
            GibbonRouter._swap(
                buyBackAmt,
                earnedToCrystlPath,
                buyBackAddress
            );

            _earnedAmt = _earnedAmt.sub(buyBackAmt);
        }
        
        return _earnedAmt;
    }

    function resetAllowances() external onlyGov {
        _resetAllowances();
    }

    function pause() external onlyGov {
        _pause();
    }

    function unpause() external onlyGov {
        _unpause();
        _resetAllowances();
    }

    function panic() external onlyGov {
        _pause();
        _emergencyVaultWithdraw();
    }

    function unpanic() external onlyGov {
        _unpause();
        _farm();
    }

    function setGov(address _govAddress) external onlyGov {
        govAddress = _govAddress;
    }
    
    function setSettings(
        uint256 _controllerFee,
        uint256 _buyBackRate,
        uint256 _withdrawFeeFactor
    ) external onlyGov {
        require(_controllerFee.add(_buyBackRate) <= feeMaxTotal, "Max fee of 5%");
        require(_withdrawFeeFactor <= withdrawFeeFactorMax, "_withdrawFeeFactor too high");
        controllerFee = _controllerFee;
        buyBackRate = _buyBackRate;
        withdrawFeeFactor = _withdrawFeeFactor;

        emit SetSettings(
            _controllerFee,
            _buyBackRate,
            _withdrawFeeFactor
        );
    }
}
