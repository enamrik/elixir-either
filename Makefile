
test:
	./scripts/restore-deps.sh
	mix test --no-start

.PHONY:test
