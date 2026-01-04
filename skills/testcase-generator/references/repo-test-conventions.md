# Repo Foundry Test Conventions

## Locations

- Keep unit tests under `contracts/test` and its subfolders.
- Mirror module structure when helpful (e.g., `contracts/test/components`, `contracts/test/BurnMintERC20`).
- Use fork tests only under `contracts/test/fork` (avoid when generating deterministic unit tests).

## File Naming

- Always use `.t.sol` suffix.
- Keep `.tree` specs alongside their matching `.t.sol` file when using bulloak.
- Prefer existing patterns:
  - `Contract.t.sol` (single file)
  - `Contract.<version>.t.sol` (versioned contracts like `.1`)
  - `Contract.<feature>.t.sol` or `Contract.<function>.t.sol`
- Examples in this repo:
  - `contracts/test/Administrable.t.sol`
  - `contracts/test/Oracle.1.t.sol`
  - `contracts/test/BurnMintERC20/BurnMintERC20.burn.t.sol`

## Base Tests, Helpers, and Mocks

- Use `forge-std/Test.sol` in all tests.
- Reuse setup helpers when they exist:
  - `contracts/test/BurnMintERC20/BaseTest.t.sol` for labeled addresses and deterministic time.
  - `contracts/test/BurnMintERC20/BurnMintERC20Setup.t.sol` for token setup and proxy wiring.
- Helpers live in `contracts/test/utils` (e.g., `UserFactory.sol`, `LibImplementationUnbricker.sol`).
- Mocks live in `contracts/test/mocks` (e.g., `RiverMock.sol`, `MockERC20.sol`).

## Style and Assertions

- Use explicit addresses with `makeAddr` or constants to keep tests deterministic.
- Expect custom errors with `abi.encodeWithSignature(...)` or revert strings when contracts use OZ access control.
- Assert events with `vm.expectEmit` when the contract surface includes events.
- Keep `setUp` deterministic: deploy, initialize, and seed balances with `deal`.

## Upgradeable/Versioned Contracts

- For versioned contracts (e.g., `.1`), keep the same suffix in the test file name.
- When a contract uses proxy patterns or storage versioning, unbrick before init:
  - `LibImplementationUnbricker.unbrick(vm, address(implementation))`
  - See `contracts/test/Oracle.1.t.sol` for an example.

## Deterministic Unit Tests Only

- Do not add fuzzing or invariant tests in this skill.
- Avoid fuzzed inputs and `vm.assume`; use concrete values and explicit edge cases instead.
