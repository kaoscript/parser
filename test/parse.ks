#![bin]
#![error(off)]

extern {
	__dirname: String
	console
	describe: Function
	it: Function
	JSON
}

import {
	'..' for parse
	'@kaoscript/chai' for expect
	'fs'
	'klaw-sync' => klaw
	'path'
}

describe('parse', func() {
	func prepare(file) {
		const root = path.dirname(file)
		const name = path.basename(file).slice(0, -3)

		it(name, func() {
			const source = fs.readFileSync(file, {
				encoding: 'utf8'
			})
			//console.log(source)

			let error = null

			try {
				error = fs.readFileSync(path.join(root, name + '.error'), {
					encoding: 'utf8'
				})
			}

			if error == null {
				let data = parse(source)
				// console.log(JSON.stringify(data, (key, value) => value == Infinity ? 'Infinity' : value, 2))

				const json = fs.readFileSync(path.join(root, name + '.json'), {
					encoding: 'utf8'
				})

				expect(data).to.eql(JSON.parse(json, (key, value) => value == 'Infinity' ? Infinity : value))

				// when AST is changed
				/* data = JSON.parse(JSON.stringify(data, (key, value) => value == Infinity ? 'Infinity' : key == 'kind' ? 0 : value, 2), (key, value) => value == 'Infinity' ? Infinity : key == 'kind' ? 0 : value)

				expect(data).to.eql(JSON.parse(json, (key, value) => value == 'Infinity' ? Infinity : key == 'kind' ? 0 : value)) */
			}
			else {
				let data

				expect(func() {
					data = parse(source)
				}).to.throw(error)

				expect(data).to.not.exist
			}
		})
	}

	const options = {
		nodir: true
		traverseAll: true
		filter: item => item.path.slice(-3) == '.ks'
	}

	for file in klaw(path.join(__dirname, 'fixtures'), options) {
		prepare(file.path)
	}
})