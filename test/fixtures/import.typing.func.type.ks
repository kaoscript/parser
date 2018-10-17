type T =
	func(value: Number): Number |
	func(value: String): String

type U =
	async func(value: Number): Number |
	async func(value: String): String

import 'foobar' {
	foo(...) => f1
	async bar()	=> b1
	baz(...): T => b2
	qux(): U => q1
}

import 'barfoo' {
	func foo(...) => f1
	async func bar()	=> b1
	func baz: T => b2
	func qux(): U => q1
}