#![bin]
#![error(off)]

extern {
	console
	process
}

import {
	'kaoscript/register'
	'mocha' => Mocha
}

func logSuccess(str) {
	console.log('\u001b[32m  ✓ \u001b[0m\u001b[90m' + str + '\u001b[0m')
}
func logError(str) {
	console.log('\u001b[31m  ✖ ' + str + '\u001b[0m')
}

class EmptyReporter {
	constructor(...)
}

const args = process.argv.slice(3)

const success = []
const errors = []

const mocha = new Mocha({
	reporter: EmptyReporter
})
mocha.checkLeaks()
mocha.addFile('./test/parse.test.ks')
mocha.grep(args[0])

mocha
	.run()
	.on('pass', (test) => {
		success.push(test.title)

		logSuccess(test.title)
	})
	.on('fail', (test, error, ...) => {
		errors.push({test, error})

		if !`\(error)`.startsWith('AssertionError:') {
			console.error(error.stack)
		}

		logError(test.title)
	})
	.on('end', () => {
		console.log()

		if success.length > 0 {
			logSuccess(success.length + ' tests passed')
		}

		if errors.length > 0 {
			logError(errors.length + ' tests failed')
		}
	})

