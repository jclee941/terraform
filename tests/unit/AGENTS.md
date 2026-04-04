# AGENTS: tests/unit — Unit Test Suite

## OVERVIEW
Go unit tests for Terraform module validation. Fast, isolated tests for module logic without infrastructure dependencies.

## STRUCTURE
```
unit/
└── lxc_config_test.go    # LXC config module unit tests
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| LXC config tests | `lxc_config_test.go` | Config rendering validation |
| Test utilities | Parent `tests/` | Shared test helpers |

## CONVENTIONS
- Use Go testing framework
- Mock external dependencies
- Fast execution (< 1s per test)
- Table-driven tests for multiple cases

## ANTI-PATTERNS
- NEVER call real APIs or provision resources
- NEVER depend on external infrastructure
- NEVER skip tests without documentation
- NEVER use `time.Sleep()` in tests

## COMMANDS
```bash
go test ./tests/unit/...          # Run unit tests
make test-unit                    # Via Makefile
```
