build:
	time node_modules/.bin/kaoscript -c src/parser.ks -o lib

test:
ifeq ($(g),)
	node_modules/.bin/mocha --colors --check-leaks --compilers ks:kaoscript/register --reporter spec
else
	node_modules/.bin/mocha --colors --check-leaks --compilers ks:kaoscript/register --reporter spec -g "$(g)"
endif

coverage:
ifeq ($(g),)
	./node_modules/@zokugun/istanbul.cover/src/cli.js
else
	./node_modules/@zokugun/istanbul.cover/src/cli.js "$(g)"
endif

clean:
	find -L . -type f \( -name "*.ksb" -o -name "*.ksh" -o -name "*.ksm" \) -exec rm {} \;

.PHONY: test coverage