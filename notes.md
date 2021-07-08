Deploy, transfer ownership, this part is simple

Crystl-Matic LP strategy: 0x8901972723fa42277cA90f7322704Ef94c1daF3a

{

	"address _vaultHealerAddress": "0x67A75f27ae8f99692eDF3e597c025D4b874c88A3",
	"address _masterHealerAddress": "0xeBCC84D2A73f0c9E23066089C6C24F4629Ef1e6d",
	"address _apeFactoryAddress": "0xCf083Be4164828f00cAE704EC15a36D711491284", // this part has changed
	"uint256 _pid": "1",
	"address _wantAddress": "0xB8e54c9Ea1616beEBe11505a419DD8dF1000E02a",
	"address _earnedAddress": "0x76bF0C28e604CC3fE9967c83b3C3F31c213cfE64",
	"uint256 _compoundMode": "0",
	"address[] _earnedToCrystlPath": [
		"0x76bF0C28e604CC3fE9967c83b3C3F31c213cfE64"
	],
	"address[] _earnedToToken0Path": [
		"0x76bF0C28e604CC3fE9967c83b3C3F31c213cfE64",
		"0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
	],
	"address[] _earnedToToken1Path": [
		"0x76bF0C28e604CC3fE9967c83b3C3F31c213cfE64"
	]
}

After deploying a strategy, call addPool(strategyAddress) on VaultHealer

In order to deposit, user must approve spending of the want (LP) token by VaultHealer. No need to approve the strategy.

871644997768781393
