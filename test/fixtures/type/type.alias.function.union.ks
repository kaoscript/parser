type D = func(value: Number): Number | String
type U = func(value: Number): Number || func(value: String): String

type M =
	func(value: Number): Number
	|
	func(value: String): String

type M2 =
	func(value: Number): Number |
	func(value: String): String

type M3 =
	func(value: Number): Number
	| func(value: String): String

type M4 =
	func(value: Number): Number ||
	func(value: String): String