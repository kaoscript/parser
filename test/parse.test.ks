#![bin]
#![error(off)]

extern {
	__dirname: String
	JSON
	console
	process

	func describe(...)
	func it(...)
}

include '../src/util.ks'

import {
	'node:fs'
	'node:path'
	'npm:@kaoscript/chai'		for expect
	'npm:kaoscript/src/fs.js'	for escapeJSON, unescapeJSON
	'npm:klaw-sync'				=> klaw
	'..'						for parse
}

var DEBUG = process.env.DEBUG == '1' || process.env.DEBUG == 'true' || process.env.DEBUG == 'on'
var SKIP_KIND = process.env.SKIP_KIND == '1' || process.env.SKIP_KIND == 'true' || process.env.SKIP_KIND == 'on'

func unescapeKind(key, value) { # {{{
	if key == 'kind' | 'assignment' {
		return 0
	}
	else {
		return unescapeJSON(key, value)
	}
} # }}}

var unescape = if SKIP_KIND set unescapeKind else unescapeJSON

var mut testings = []

if process.argv[2].endsWith('test/parse.dev.ks') && process.argv.length > 3 {
	var args = process.argv[3].split(' ')

	if args[0] == 'parse' {
		if !args[1].includes('|') && !args[1].includes('[') {
			testings = args.slice(1)
		}
		else {
			testings = args
		}
	}
}

func prepare(file) { # {{{
	var root = path.dirname(file)
	var name = path.basename(file).slice(0, -3)

	if testings.length > 0 && !testings.some((testing, ...) => name.startsWith(testing) || testing.startsWith(name)) {
		return
	}

	it(name, () => {
		var source = fs.readFileSync(file, {
			encoding: 'utf8'
		})

		var mut error = null

		try {
			error = fs.readFileSync(path.join(root, name + '.error'), {
				encoding: 'utf8'
			})
		}

		if ?error {
			var mut data = null

			try {
				data = parse(source)
			}
			catch ex {
				if ?ex.lineNumber {
					try {
						expect(`\(ex.message) at line \(ex.lineNumber) and column \(ex.columnNumber)`).to.equal(error)
					}
					catch ex2 {
						if DEBUG {
							console.log(`\(ex.message) at line \(ex.lineNumber) and column \(ex.columnNumber)`)
						}

						throw ex2
					}
				}
				else {
					throw ex
				}
			}

			if ?data && DEBUG {
				console.log(JSON.stringify(data, escapeJSON, 2))
				console.log('>----------------------------------------------------------<')
				console.log('It should throw an error')
			}

			expect(data).to.not.exist
		}
		else {
			var late data

			try {
				data = parse(source)
			}
			catch ex {
				if DEBUG {
					ex.message += ` (\(file):\(ex.lineNumber):\(ex.columnNumber))`
				}

				throw ex
			}

			var mut json = null

			try {
				json = fs.readFileSync(path.join(root, name + '.json'), {
					encoding: 'utf8'
				})
			}
			catch ex {
				if DEBUG {
					console.log(JSON.stringify(data, escapeJSON, 2))
				}

				throw ex
			}

			try {
				expect(JSON.parse(JSON.stringify(data, escapeJSON), unescape)).to.eql(JSON.parse(json, unescape))
			}
			catch ex {
				if DEBUG {
					console.log(JSON.stringify(data, escapeJSON, 2))
				}

				throw ex
			}
		}
	})
} # }}}

describe('parse', () => {
	var files = klaw(path.join(__dirname, 'fixtures'), {
		nodir: true
		traverseAll: true
		filter: (item) => item.path.slice(-3) == '.ks'
	})

	for var file in files {
		prepare(file.path)
	}
})

