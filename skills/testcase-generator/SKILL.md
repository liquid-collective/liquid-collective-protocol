---
name: testcase-generator
description: Generate deterministic Foundry unit tests for Solidity contracts in this repo using bulloak and the Branching Tree Technique (BTT). Use when asked to create unit tests for a specific contract or all contracts in a folder (e.g., "generate test cases for the contract <contract-name>" or "generate test cases for the contracts in the folder"), following contracts/test conventions and avoiding fuzzing or invariant tests.
---

# Testcase Generator

## Overview

Generate deterministic Foundry unit tests for Solidity contracts in this repo, using bulloak and BTT to define test scenarios in `.tree` specs before implementing Solidity tests.

## Workflow

1. Locate target contract(s) and their dependencies in `contracts/src` (or related subfolders), and confirm any version suffixes (e.g., `.1`).
2. Scan `contracts/test` for existing tests or setup helpers for the same module and reuse them when appropriate.
3. Draft a `.tree` spec per test file using BTT to enumerate conditions and actions.
4. Scaffold the test file with bulloak, then fill in test bodies deterministically.
5. Build a deterministic `setUp` that deploys and initializes contracts, including proxy/unbrick steps when needed.
6. Write deterministic unit tests that cover happy paths, access control, revert paths, event emission, state transitions, and boundary conditions.
7. Split tests per contract or feature; avoid monolithic test files when multiple contracts are involved.

## Foundry Conventions

- Import `forge-std/Test.sol` and use `vm.*` cheatcodes for deterministic control.
- Prefer explicit constants and `makeAddr` helpers; avoid fuzzed inputs and `vm.assume`.
- Use `vm.expectRevert` with custom errors or revert strings as seen in nearby tests.
- Use `vm.expectEmit` for event assertions when events are part of the contract surface.

## Bulloak Conventions

- Store `.tree` specs alongside their `.t.sol` counterparts in the same folder.
- Keep tree roots aligned with the test contract name (and use `Contract::function` only when multiple trees share a contract).
- Ensure condition labels are identifier-friendly because bulloak turns them into modifiers.
- If `bulloak` is not installed, ask the user to run `cargo install bulloak` rather than installing automatically.
- Use `bulloak scaffold -w --vm-skip` when you need generated tests to compile before implementation; remove `vm.skip(true)` after filling the test bodies.
- Use `--format-descriptions` consistently in `scaffold` and `check` if you want normalized comments.
- Run `bulloak check` (and `--fix` when needed) to keep `.tree` and `.t.sol` in sync.

## References

- Read `references/repo-test-conventions.md` before writing tests to match repo layout, naming, and helper usage.
- Read `references/bulloak-btt.md` for the BTT spec rules and bulloak CLI details.
