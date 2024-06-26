test:
ifeq ($(g),)
	node_modules/.bin/mocha --colors --check-leaks --require kaoscript/register --reporter spec "test/*.test.ks"
else
	node_modules/.bin/mocha --colors --check-leaks --require kaoscript/register --reporter spec -g "$(g)" "test/*.test.ks"
endif

coverage:
ifeq ($(g),)
	./node_modules/@zokugun/istanbul.cover/src/cli.js
else
	./node_modules/@zokugun/istanbul.cover/src/cli.js "$(g)"
endif

patch:
	npx kaoscript ./scripts/patch.ks$(if $(value dir), "$(dir)")

clean:
	npx kaoscript --clean

cls:
	printf '\033[2J\033[3J\033[1;1H'

update:
	@make clean
	rm -rf node_modules package-lock.json
	nrm use local
	npm i

local:
	nrm use local
	npm unpublish @kaoscript/parser --force
	npm publish

dev: export DEBUG = 1
dev: export SKIP_KIND = 0
dev:
	@# clear terminal
	@make cls

	@# tests
	npx kaoscript test/parse.dev.ks "parse require.enum.empty"

.PHONY: test coverage
