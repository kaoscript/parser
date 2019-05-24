[@kaoscript/parser](https://github.com/kaoscript/parser)
========================================================

[![kaoscript](https://img.shields.io/badge/language-kaoscript-orange.svg)](https://github.com/kaoscript/kaoscript)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![NPM Version](https://img.shields.io/npm/v/@kaoscript/parser.svg?colorB=green)](https://www.npmjs.com/package/@kaoscript/parser)
[![Dependency Status](https://badges.depfu.com/badges/3c221673253adbcd9f9672933837315e/overview.svg)](https://depfu.com/github/kaoscript/parser)
[![Build Status](https://travis-ci.org/kaoscript/parser.svg?branch=master)](https://travis-ci.org/kaoscript/parser)
[![CircleCI](https://circleci.com/gh/kaoscript/parser/tree/master.svg?style=shield)](https://circleci.com/gh/kaoscript/parser/tree/master)
[![Coverage Status](https://img.shields.io/coveralls/kaoscript/parser/master.svg)](https://coveralls.io/github/kaoscript/parser)

Parse kaoscript files and generates an abstract syntax tree.

Documentation available at [kaoscript](https://github.com/kaoscript/kaoscript).

Evolution
---------

- July-August 2016: since I didn't wanted to handwriting the parser, I've used a **LL(*)** parser. Slow since lot of backtracking.

- August 2016 - May 2017: I've used [Jison](https://zaa.ch/jison/) to generate a **SLR** parser. Faster (10x) but the syntax was getting complex and tricky.

- May 2017: I've tried [chevrotain](https://github.com/SAP/chevrotain) (a fast **LL(4)** parser).

	I didn't choice it because:
	- You have to distinguish ambiguous rules, complexify the syntax
	- You can't switch the tokenizer when parsing

- May 2017 - \*: Handwritten parser. It's basically a **LL(1)** parser with few lookheads.

	Advantages:
	- at least 2x times faster than Jison
	- manageable code
	- better support of space
	- `macro`

License
-------

[MIT](http://www.opensource.org/licenses/mit-license.php) &copy; Baptiste Augrain