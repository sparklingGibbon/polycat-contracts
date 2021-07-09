
PolyCrystal vaults

The strategies consist of StrategyMasterHealer > BaseStrategyApeLPSingle > BaseStrategyApeLP > BaseStrategy. The StrategyMasterHealer is equipped to function with any of the "stake LP, earn crystal" farms.

The central hub for the vaults is VaultHealer which accepts funds and distributes them to the strategies. It is the owner of the strategies and most of the functions are restricted to onlyOwner. Users normally interact via VaultHealer. Users should authorize VaultHealer for the LP tokens they intend to deposit.

Routing has been simplified and code from ApeRouter has been adapted to a GibbonRouter library, bypassing the slippage and deadline checks, which as noted in the PolyCat audits, had no effect.

Compounding has been switched from a gov address only function to automatic, happening across all vaults whenever any deposit or withdrawal is made. To mitigate a hypothetical risk of exploitation, this can be restricted. Such a risk would affect temporarily only a portion of compounded earnings and not principal investments.

Whether all deposits and withdrawals compound all vaults can be toggled. By default, autocompound is enabled and compounding is unrestricted.

    //0: compound by anyone; 1: EOA only; 2: restricted to operators
    uint public compoundLock;
    bool public autocompoundOn;
    function setCompoundMode(uint lock, bool autoC) external onlyOwner {
        compoundLock = lock;
        autocompoundOn = autoC;
    }
    
