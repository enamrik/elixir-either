
test:
	./scripts/restore-deps.sh
	mix test --no-start

test_one:
	mix test --no-start --only one

.PHONY:test
