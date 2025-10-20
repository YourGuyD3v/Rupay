-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    Fund your contract with LINK"
	@echo ""
	@echo "  make test [ARGS=...]\n    example: make test ARGS=\"--mt testDepositAndMint\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install openzeppelin/openzeppelin-contracts@v5.0.0 --no-commit && forge install smartcontractkit/chainlink@v2.7.0 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test $(ARGS)

coverage :; forge coverage --report debug > coverage-report.txt

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployRup.s.sol:DeployRup $(NETWORK_ARGS)

verify:
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args $(CONSTRUCTOR_ARGS) --compiler-version v0.8.19 $(CONTRACT_ADDRESS) $(CONTRACT_NAME) $(ETHERSCAN_API_KEY)