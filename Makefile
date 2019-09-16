test:
ifeq ($(g),)
	node_modules/.bin/mocha --colors --check-leaks --require kaoscript/register --reporter spec
else
	node_modules/.bin/mocha --colors --check-leaks --require kaoscript/register --reporter spec -g "$(g)"
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
	npx kaoscript --clean

.PHONY: test coverage