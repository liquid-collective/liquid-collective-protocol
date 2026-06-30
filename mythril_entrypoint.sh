#! /bin/sh

# Mythril resolves the Solidity compiler through py-solc-x, which by default
# downloads solc from solc-bin.ethereum.org at runtime. The mythril image runs
# as a non-root user, so the GitHub-mounted HOME (/github/home) is not writable
# for the solcx cache. Point solcx at a writable directory and seed it with the
# solc binary pre-fetched on the runner (mounted via the workspace) so the
# analysis never reaches out to solc-bin.ethereum.org.
export HOME=/tmp
export SOLCX_BINARY_PATH=/tmp/.solcx
mkdir -p "$SOLCX_BINARY_PATH"

if [ -f "${GITHUB_WORKSPACE}/.solcx/solc-v0.8.34" ]; then
  cp "${GITHUB_WORKSPACE}/.solcx/solc-v0.8.34" "$SOLCX_BINARY_PATH/solc-v0.8.34"
  chmod +x "$SOLCX_BINARY_PATH/solc-v0.8.34"
fi

/usr/local/bin/myth $@ -o markdown | tee mythril_output.md