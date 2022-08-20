func foo(x, _, y) {
	console.log(x, y)
}

func bar(_, x, y) {
	console.log(x, y)
}

func baz(x, y, _) {
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