 #!/usr/bin/env kaoscript

extern {
	__dirname
	JSON
	process
}

import {
	'node:fs'
	'node:path'
	'npm:klaw-sync' => klaw

	'..' for parse
}

var args = process.argv.slice(3)

var filter = if args.length == 1 {
	var directory = args[0]

	set (item) => item.path.slice(-3) == '.ks' && path.basename(path.dirname(item.path)) == directory
}
else {
	set (item) => item.path.slice(-3) == '.ks'
}

func prepare(file: String): Void {
	var root = path.dirname(file)
	var name = path.basename(file).slice(0, -3)
	var mut data = fs.readFileSync(file, {
		encoding: 'utf8'
	})

	echo(name)

	var mut error: String? = null

	try {
		error = fs.readFileSync(path.join(root, name + '.error'), {
			encoding: 'utf8'
		})
	}

	if !?error {
		try {
			data = parse(data)

			data = JSON.stringify(data, (key, value?) => {
				if value == Infinity {
					return 'Infinity'
				}

				return value
			}, 2)

			fs.writeFileSync(path.join(root, name + '.json'), data, {
				encoding: 'utf8'
			})
		}
		catch err {
			echo(err)
		}
	}
}

var files = klaw(path.join(__dirname, '..', 'test', 'fixtures'), {
	nodir: true
	traverseAll: true
	filter
})

for var file in files {
	prepare(file.path)
}
