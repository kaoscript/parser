type T =
	func(value: Number): Number |
	func(value: String): String

type U =
	async func(value: Number): Number |
	async func(value: String): String

import 'foobar' {
	foo(...)
	async bar()
	baz(...): T
	qux(): U
} => {
	foo: f1
	bar: b1
	baz: b2
	qux: q1
}

import 'barfoo' {
	func foo(...)
	async func bar()
	func baz: T
	func qux(): U
} => {
	foo: f1
	bar: b1
	baz: b2
	qux: q1
}