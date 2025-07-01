-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

#quick install necessary dependencies
install :; forge install @openzeppelin/openzeppelin-contracts --no-commit && git clone https://github.com/foundry-rs/foundry.git

NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account **** --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

deploy:
	@forge script script/TestnetDeploy.s.sol:DeployScript $(NETWORK_ARGS) 
