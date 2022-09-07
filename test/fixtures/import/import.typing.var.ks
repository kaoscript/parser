import 'path' {
	var sep: String
	func basename(path: String): String
	func dirname(path: String): String
	func join(...paths: String): String
	func relative(from: String, to: String): String
}