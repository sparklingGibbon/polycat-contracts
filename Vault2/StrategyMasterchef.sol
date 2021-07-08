// SPDX-License-Identifier: MIT

/*
Join us at PolyCrystal.Finance!
█▀▀█ █▀▀█ █░░ █░░█ █▀▀ █▀▀█ █░░█ █▀▀ ▀▀█▀▀ █▀▀█ █░░ 
█░░█ █░░█ █░░ █▄▄█ █░░ █▄▄▀ █▄▄█ ▀▀█ ░░█░░ █▄▄█ █░░ 
█▀▀▀ ▀▀▀▀ ▀▀▀ ▄▄▄█ ▀▀▀ ▀░▀▀ ▄▄▄█ ▀▀▀ ░░▀░░ ▀░░▀ ▀▀▀
*/

pragma solidity 0.6.12;

import "./interfaces/IMasterHealer.sol";

import "./BaseStrategyApeLPSingle.sol";

contract StrategyMasterHealer is BaseStrategyApeLPSingle {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IMasterHealer public masterHealer;
    uint256 public pid;

    constructor(
        address _vaultHealerAddress,
        address _masterHealerAddress,
        address _apeFactoryAddress,
        uint256 _pid,
        address _wantAddress,
        address _earnedAddress,
        uint256 _compoundMode,
        address[] memory _earnedToCrystlPath,
        address[] memory _earnedToToken0Path,
        address[] memory _earnedToToken1Path
    ) public {
        govAddress = msg.sender;
        vaultHealerAddress = _vaultHealerAddress;
        masterHealer = IMasterHealer(_masterHealerAddress);
        apeFactoryAddress = _apeFactoryAddress;

        wantAddress = _wantAddress;
        token0Address = IApePair(wantAddress).token0();
        token1Address = IApePair(wantAddress).token1();

        pid = _pid;
        earnedAddress = _earnedAddress;
    
        compoundMode = _compoundMode;

        earnedToCrystlPath = _earnedToCrystlPath;
        earnedToToken0Path = _earnedToToken0Path;
        earnedToToken1Path = _earnedToToken1Path;

        transferOwnership(vaultHealerAddress);
        
        _resetAllowances();
    }

    function _vaultDeposit(uint256 _amount) internal override {
        masterHealer.deposit(pid, _amount);
    }
    
    function _vaultWithdraw(uint256 _amount) internal override {
        masterHealer.withdraw(pid, _amount);
    }
    
    function _vaultHarvest() internal override {
        masterHealer.withdraw(pid, 0);
    }
    
    function vaultSharesTotal() public override view returns (uint256) {
        (uint256 amount,) = masterHealer.userInfo(pid, address(this));
        return amount;
    }
     
    function wantLockedTotal() public override view returns (uint256) {
        return IERC20(wantAddress).balanceOf(address(this))
            .add(vaultSharesTotal());
    }

    function _resetAllowances() internal override {
        IERC20(wantAddress).safeApprove(address(masterHealer), uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            address(masterHealer),
            uint256(-1)
        );
    }
    
    function _emergencyVaultWithdraw() internal override {
        masterHealer.emergencyWithdraw(pid);
    }
}
