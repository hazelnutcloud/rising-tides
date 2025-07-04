# Include .env file if it exists
-include .env

.PHONY: build test deploy deploy-sepolia deploy-mainnet clean

build:
	forge build

test:
	forge test -vvv

deploy-anvil:
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(ANVIL_RPC_URL) \
		--broadcast \
		--interactives 1 \
		-vvvv

deploy-risetestnet:
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(RISE_TESTNET_RPC_URL) \
		--broadcast \
		-- interactives 1 \
		--verify \
		--verifier blockscout \
		--verifier-url https://explorer.testnet.riselabs.xyz/api/ \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

deploy-rise:
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(RISE_RPC_URL) \
		--broadcast \
		--ledger \
		--verify \
		--verifier blockscout \
		--verifier-url https://explorer.riselabs.xyz/api/ \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

clean:
	forge clean
	rm -rf deployments/
