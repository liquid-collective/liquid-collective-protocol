.PHONY: foundry lib yarn install test lint test-lint

foundry:
	echo "Install foundry"
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

lib:
	git submodule update --init --recursive 
	
yarn:
	yarn && yarn link_contracts
	
install: foundry lib yarn

test:
	forge test -vvv --gas-report --no-match-contract HEAVY_FUZZING

test-heavy:
	forge test -vvv --gas-report --match-contract HEAVY_FUZZING

lint:
	forge build --force
	forge fmt

test-lint:
	forge build --force
	forge fmt --check

artifacts-mainnet:
	yarn hh run gen_root_artifacts.ts --network mainnet
	yarn hh run gen_meta_artifacts.ts --network mainnet

artifacts-goerli:
	yarn hh run gen_root_artifacts.ts --network goerli
	yarn hh run gen_meta_artifacts.ts --network goerli

artifacts-mockedGoerli:
	yarn hh run gen_root_artifacts.ts --network mockedGoerli
	yarn hh run gen_meta_artifacts.ts --network mockedGoerli

