foundry:
	echo "Install foundry"
	curl -L https://foundry.paradigm.xyz | bash
	foundryup

lib:
	git submodule update --init --recursive 

install: foundry lib
	yarn && yarn link_contracts

test:
	yarn test

test-lint:
	yarn lint-test