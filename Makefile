build:
	node_modules/.bin/jison ./src/parser.jison -o ./lib/parser.js -p slr > /dev/null

test:
ifeq ($(g),)
	node_modules/.bin/mocha --colors --reporter spec
else
	node_modules/.bin/mocha --colors --reporter spec -g "$(g)"
endif

.PHONY: test