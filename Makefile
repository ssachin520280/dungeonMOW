-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

install :; forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install OpenZeppelin/openzeppelin-contracts --no-commit

deploy-shape-sepolia :
	@forge script script/DeployDungeonMOW.s.sol:DeployDungeonMOW --rpc-url $(SHAPE_SEPOLIA_RPC_URL) --account myaccount --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv