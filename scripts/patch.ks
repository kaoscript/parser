 #!/usr/bin/env kaoscript

extern {
	__dirname
	console
	JSON
}

import {
	'node:fs'
	'node:path'
	'npm:klaw-sync' => klaw

	'..' for parse
}

func prepare(file: String): Void {
	var root = path.dirname(file)
	var name = path.basename(file).slice(0, -3)
	var mut data = fs.readFileSync(file, {
		encoding: 'utf8'
	})

	console.log(name)

	var mut error: String? = null

	try {
		error = fs.readFileSync(path.join(root, name + '.error'), {
			encoding: 'utf8'
		})
	}

	if ?error {
		try {
			parse(data)
		}
	}
	else {
		try {
			data = parse(data)

			data = JSON.stringify(data, (key, value) => {
				if value == Infinity {
					return 'Infinity'
				}

				return value
			}, 2)

			fs.writeFileSync(path.join(root, name + '.json'), data, {
				encoding: 'utf8'
			})
		}
	}
}

var files = klaw(path.join(__dirname, '..', 'test', 'fixtures'), {
	nodir: true
	traverseAll: true
	filter: (item) => item.path.slice(-3) == '.ks'
})

for var file in files {
	prepare(file.path)
}
