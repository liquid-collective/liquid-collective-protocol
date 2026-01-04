# Bulloak + BTT Quick Reference

## Placement and Naming

- Keep each `.tree` spec in the same folder as its matching `.t.sol`.
- Match filenames exactly: `Foo.tree` -> `Foo.t.sol`.
- Use one `.tree` per test file unless you need multiple trees in the same file.

## Tree Structure Rules

- Root node is the test contract name (e.g., `FooTest`).
- Branch characters must be `├──` and `└──`.
- Conditions start with `when` or `given` (case-insensitive).
- Actions start with `it` (case-insensitive).
- Action descriptions are child nodes of an action.
- Lines starting with `//` are comments and removed in scaffold output.
- Condition labels must be identifier-friendly (they become modifiers).

### Single Tree Example

```tree
FooTest
├── When caller is admin
│   └── It should succeed.
└── When caller is not admin
    └── It should revert.
        └── Because only admin may call.
```

### Multiple Trees in One File

Use `Contract::function` when defining multiple trees in the same file, and keep
the contract identifier consistent across roots.

```tree
Foo::setOwner
├── It should never revert.
└── When caller is not admin
    └── It should revert.


Foo::pause
└── It should emit Paused.
```

## Bulloak Commands

- Scaffold to stdout:
  - `bulloak scaffold path/to/spec.tree`
- Scaffold and write files:
  - `bulloak scaffold -w path/to/spec.tree`
  - Use `-f` to overwrite existing `.t.sol`.
- Ensure scaffolded tests compile:
  - `bulloak scaffold -w -S path/to/spec.tree`
  - `-S` adds `vm.skip(true);` and imports `forge-std/Test.sol`.
- Skip generating modifier definitions:
  - `bulloak scaffold -m ...`
- Normalize comment formatting:
  - `bulloak scaffold -F ...`
- Validate spec vs implementation:
  - `bulloak check path/to/spec.tree`
  - `bulloak check --fix path/to/spec.tree`

## Output Notes

- One modifier per unique condition title (reused across the tree).
- Top-level actions must be unique; duplicates are semantic errors.
- Name collisions for non-top-level actions are disambiguated by ancestor
  condition titles or a numeric suffix.

## Deterministic Tests Only

- Do not add fuzz tests or invariants.
- Replace `vm.skip(true)` with concrete assertions once implemented.
