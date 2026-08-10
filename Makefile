.PHONY: foundry lib yarn install test lint test-lint size

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
	forge test -vvv --gas-report --no-match-contract "HEAVY_FUZZING"

test-heavy:
	forge test -vvv --gas-report --match-contract HEAVY_FUZZING

# Checks every deployable production contract against the EIP-170 runtime limit.
# RiverV1 has ~1.6KB of headroom, so run this on any change that touches River or the
# oracle report struct. Set MIN_RUNTIME_MARGIN to also fail on a too-thin margin.
size:
	./scripts/check_contract_sizes.sh

lint:
	forge build --force
	forge fmt

test-lint:
	forge build --force
	forge fmt --check

artifacts-mainnet:
	yarn hh run gen_root_artifacts.ts --network mainnet
	yarn hh run gen_meta_artifacts.ts --network mainnet
