extern {
	func parseFloat(...): Number
	func parseInt(...): Number

	sealed class Array
	sealed namespace Math
	sealed class RegExp
	sealed class String
	sealed class SyntaxError
}

disclose Array {
	length: Number
	indexOf(searchElement, fromIndex: Number = 0): Number
	join(separator: String?): String
	pop(): Any?
	push(...elements?): Number
	shift(): Any?
	slice(begin: Number = 0, end: Number = -1): Array
	some(callback): Boolean
	splice(start: Number = 0, deleteCount: Number = 0, ...items?)
	sort(compare: Function = null): Array
	unshift(...elements?): Number
}

disclose Math {
	pow(...): Number
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
	slice(beginIndex: Number, endIndex: Number = -1): String
	split(separator: RegExp | String = null, limit: Number = -1): Array<String>
	startsWith(search: String, position: Number = 0): Boolean
	substr(start: Number, length: Number = -1): String
	substring(indexStart: Number, indexEnd: Number = -1): String
}

type RegExpExecArray = Array<String?> & {
    index: Number
    input: String
}
