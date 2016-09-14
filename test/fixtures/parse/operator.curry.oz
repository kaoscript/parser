func foo(intro, name) {
	return `\(intro) \(name)!`
}

let bar = foo^^('Hello')

console.log(bar('world'))