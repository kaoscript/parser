func foo(intro, name) {
	return `\(intro) \(name)!`
}

var dyn bar = foo^^('Hello')

console.log(bar('world'))