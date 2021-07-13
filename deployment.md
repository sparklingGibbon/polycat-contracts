#### Deployment info

I mentally cannot do JavaScript right now so I won't sit around wasting any more time not doing it, when there are several other people who could do the job in 20 minutes. I'll tackle this stuff when I am ready, and that day is not today. It's a strange limitation and the work seems simple enough, but I can't do it any more than I can comprehend why it's so difficult for me at this time.

Instead I provide plaintext documentation, in the hope that the audit is easy and the final deployment takes only 10 minutes.

##### BaseStrategy.sol

This is based on the Polycat file of the same name. It is stripped down in a few ways. The "safeswap" function was neither particularly safe nor efficient, so I removed it. Routing functions are moved to the GibbonRouter contract (may be referred to as a library in prior docs), which this inherits. Fundamentally, this file tracks the depositor's share of the total vault, and it's good at what it does. I've left the basic logic intact. What is not intact is the multitude of ways it could extract wealth from user funds. However, we like to burn CRYSTL, so burn CRYSTL it does. The CRYSTL burn fee is 2%, configurable up to a maximum of 5%.

deposit(), \_farm(), and withdraw() are the basic functions for managing funds. These are onlyOwner functions, and the owner is the VaultHealer contract. The strategy itself is ignorant of end users. The gov address is the deployer by default, with the ability to set the burn fee, set a new gov address, pause the contract, or trigger an emergency withdrawal from the MasterHealer. The gov cannot take the funds for himself; funds can only be removed via the VaultHealer.

##### GibbonRouter.sol

This is an abstract contract I created using the logic from ApeRouter (standard Uniswap v2 stuff). Routing is frustrating and misunderstood for a lot of contract developers, and these misunderstandings were reflected in the Polycat code. At some point for future development I will make this more generic, accepting different fees, factories, and and initcodehashes. For now, this is fully compatible with any current and foreseeable Polygon ApeSwap liquidity pair, for standard ERC-20 tokens. It's untested with fee-on-transfer tokens and I suspect those wouldn't work. Essentially, this is ApeRouter but built-in and more efficient and forgiving for internal use.

##### BaseStrategyApeLP.sol

This has one function, a convertDustToEarned function. I changed it to onlyGov because dust accumulation should no longer be a common concern. The most likely use of this would be to waste tiny amounts of user funds. I kept it just in case.

##### BaseStrategyApeLPSingle.sol

This contains earn() which is the compounding function. Originally, it was designed to be run by a bot at the gov address. I modified it to be controlled by VaultHealer. A maximum of one time per block, it collects earnings, pays the burn fee, then makes LP tokens from the rest. Pretty typical compounding here. I tried to eliminate the minor problem of token dust accumulating by pseudorandomly alternating the order in which the tokens are purchased; this is computationally cheap and safe, whether it's successful or not.

StrategyMasterHealer.sol

This completes the strategy implementation. One of these will need to be deployed for each pool where we want a vault. As the strategy handles its own routing via GibbonRouter, no external router needs to be approved to transfer tokens out. All token paths must still be specified in the constructor. The new require checks should make this nearly foolproof. We want to use established liquidity pairs in as few steps as possible. For example, to convert WETH to crystl, we'd use \[wethAddr, maticAddr, crystlAddr\]. "Earned to crystl" should generally just be \[crystlAddr\].

##### VaultHealer.sol

This is the central contract responsible for all user data and external access to funds. The Polycat logic is preserved here. The new standard behavior is to compound all pools each time anyone does any deposit or withdraw transaction. Compounding can also be executed via compoundAll(). If a security concern requires it, we can restrict compounding to EOAs or to a limited list of operator addresses. Compounding can also be decoupled from deposit and withdraw. These are configured using setCompoundMode().

If compounding were to fail at any point for any pool, the exception is caught and logged. Any problem with one vault should not be expected to affect users of the other pools.

The privileged owner address can change the compound mode. The owner can also designate operator addresses which may compound regardless of the lock and perform alternate withdraw and deposit functions. The alternate withdraw takes funds allocated to msg.sender and sends them to the \_to address. The alternate deposit takes funds from msg.sender and allocates them to \_to. Owner and operators have no ability to steal user funds.

##### Deployment checklist:

* Deploy VaultHealer contract
* Deploy strategy contracts
* for each strategy address: 
	* VaultHealer.addPool(strategyAddress)
	* Set gov address
* Set VaultHealer owner
