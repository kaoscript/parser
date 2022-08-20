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
	node ./scripts/patch.js

clean:
	node_modules/.bin/kaoscript --clean

cls:
	printf '\033[2J\033[3J\033[1;1H'

update:
	rm -rf node_modules package-lock.json
	nrm use local
	npm i
	@make clean

local:
	nrm use local
	npm unpublish @kaoscript/parser --force
	npm publish

dev: export DEBUG = 1
dev:
	@# clear terminal
	@make cls

	@# tests
	npx kaoscript test/parse.dev.ks "parse test"

.PHONY: test coverage
