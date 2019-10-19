func foo(x,, y) {
	console.log(x, y)
}

func bar(, x, y) {
	console.log(x, y)
}

func baz(x, y,) {
	console.log(x, y)
}

func qux(x, ..., y) {
	console.log(x, y)
}

func quux(..., x, y) {
	console.log(x, y)
}

func corge(x, y, ...) {
	console.log(x, y)
}

func grault(...) {
}