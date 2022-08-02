#![bin]
#![error(off)]

extern {
	__dirname: String
	console
	JSON
	process

	func describe(...)
	func it(...)
}

import {
	'..'					for parse
	'@kaoscript/chai'		for expect
	'fs'
	'kaoscript/src/fs.js'	for escapeJSON, unescapeJSON
	'klaw-sync'				=> klaw
	'path'
}

var debug = process.env.DEBUG == '1' || process.env.DEBUG == 'true' || process.env.DEBUG == 'on'
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
				try {
					expect(`\(ex.message) at line \(ex.lineNumber) and column \(ex.columnNumber)`).to.equal(error)
				}
				catch ex2 {
					if debug {
						console.log(ex.message)
					}

					throw ex2
				}
			}

			if ?data && debug {
				console.log(JSON.stringify(data, escapeJSON, 2))
				console.log('>----------------------------------------------------------<')
				console.log('It should throw an error')
			}

			expect(data).to.not.exist
		}
		else {
			var data = parse(source)

			var mut json = null

			try {
				json = fs.readFileSync(path.join(root, name + '.json'), {
					encoding: 'utf8'
				})
			}
			catch ex {
				if debug {
					console.log(JSON.stringify(data, escapeJSON, 2))
				}

				throw ex
			}

			try {
				expect(JSON.parse(JSON.stringify(data, escapeJSON), unescapeJSON)).to.eql(JSON.parse(json, unescapeJSON))
			}
			catch ex {
				if debug {
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

