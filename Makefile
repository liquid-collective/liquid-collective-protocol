.PHONY: foundry lib install test lint test-lint

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
	yarn test

lint:
	forge build --force
	forge fmt

test-lint:
	forge build --force
	forge fmt --check