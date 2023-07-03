#!/usr/bin/env kaoscript

extern {
	__dirname
	console
	JSON
}

import {
	'node:child_process' for exec
	'node:fs'
	'node:path'
}

var CHANGE_REGEX = /^[+-]\s/
var FILE_REGEX = /^--- a\/(test\/.*\.json)$/

var output = await exec('git --no-pager diff -U0 test/*.json', {
	maxBuffer: 8 * 1024 * 1024
})
var stages = []

var mut file = ''
var mut changes = 0

for var line in output.split(/\r?\n/) {
	if var match ?= FILE_REGEX.exec(line) {
		if #file && changes == 0 {
			console.log(`- staging: \(file)`)

			stages.push(file)
		}

		file = match[1]
		changes = 0
	}
	else if CHANGE_REGEX.test(line) {
		if line.indexOf('"kind"') == -1 {
			// console.log(line)
			changes += 1
		}
	}
}

if #file && changes == 0 {
	console.log(`- staging: \(file)`)

	stages.push(file)
}

// console.log(stages.length)

await exec(`git add \(stages.join(' '))`)
