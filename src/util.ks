extern {
	console

	func parseFloat(...): Number
	func parseInt(...): Number

	sealed class RegExp
	sealed class String
	sealed class SyntaxError
}

type RegExpExecArray = Array<String?> & {
    index: Number
    input: String
}

disclose RegExp {
	source: String
	global: Boolean
	ignoreCase: Boolean
	multiline: Boolean
	exec(str: String, index: Number = 0): RegExpExecArray?
	test(str: String): Boolean
	toString(): String
}

disclose String {
	length: Number
	charCodeAt(index: Number): Number
	replace(pattern: RegExp | String, replacement: Function | String): String
	substr(start: Number, length: Number = -1): String
	substring(indexStart: Number, indexEnd: Number = -1): String
}