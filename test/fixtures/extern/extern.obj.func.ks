extern foobar: {
	foo(...)
	async bar()
	baz(value: Number): Number
	baz(value: String): String
	async qux(value: Number): Number
	async qux(value: String): String
}

extern barfoo: {
	func foo(...)
	async func bar()
	func baz(value: Number): Number
	func baz(value: String): String
	async func qux(value: Number): Number
	async func qux(value: String): String
}