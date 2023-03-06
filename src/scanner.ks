enum Token {
	INVALID
	ABSTRACT
	AMPERSAND
	AMPERSAND_AMPERSAND
	AMPERSAND_AMPERSAND_EQUALS
	AS
	AS_EXCLAMATION
	AS_QUESTION
	ASTERISK
	ASTERISK_DOLLAR_LEFT_ROUND
	ASTERISK_EQUALS
	ASYNC
	AT
	ATTRIBUTE_IDENTIFIER
	AUTO
	AWAIT
	BACKSLASH
	BINARY_NUMBER
	BITMASK
	BLOCK
	BREAK
	BUT
	CARET
	CARET_CARET
	CARET_CARET_CARET
	CARET_CARET_EQUALS
	CARET_CARET_LEFT_ROUND
	CARET_DOLLAR_LEFT_ROUND
	CATCH
	CLASS
	CLASS_VERSION
	COLON
	COLON_EXCLAMATION
	COLON_QUESTION
	COMMA
	CONTINUE
	DECIMAL_NUMBER
	DISCLOSE
	DO
	DOT
	DOT_DOT
	DOT_DOT_DOT
	DOWN
	DROP
	DYN
	ELSE
	ELSE_IF
	ENUM
	EOF
	EQUALS
	EQUALS_EQUALS
	EQUALS_RIGHT_ANGLE
	EXCLAMATION
	EXCLAMATION_EQUALS
	EXCLAMATION_EXCLAMATION
	EXCLAMATION_HASH_EQUALS
	EXCLAMATION_QUESTION
	EXCLAMATION_QUESTION_EQUALS
	EXCLAMATION_TILDE
	EXPORT
	EXTENDS
	EXTERN
	EXTERN_IMPORT
	EXTERN_REQUIRE
	FALLTHROUGH
	FINAL
	FINALLY
	FOR
	FROM
	FROM_TILDE
	FUNC
	GET
	HASH
	HASH_A_LEFT_ROUND
	HASH_E_LEFT_ROUND
	HASH_EQUALS
	HASH_EXCLAMATION
	HASH_EXCLAMATION_LEFT_SQUARE
	HASH_HASH
	HASH_HASH_EQUALS
	HASH_J_LEFT_ROUND
	HASH_LEFT_ROUND
	HASH_LEFT_SQUARE
	HASH_S_LEFT_ROUND
	HASH_W_LEFT_ROUND
	HEX_NUMBER
	IDENTIFIER
	IF
	IMPL
	IMPORT
	IMPORT_LITERAL
	IN
	INCLUDE
	INCLUDE_AGAIN
	INTERNAL
	IS
	IS_NOT
	LATE
	LATEINIT
	LEFT_ANGLE
	LEFT_ANGLE_EQUALS
	LEFT_ANGLE_LEFT_ANGLE
	LEFT_ANGLE_LEFT_ANGLE_EQUALS
	LEFT_ANGLE_MINUS
	LEFT_CURLY
	LEFT_ROUND
	LEFT_SQUARE
	MACRO
	MATCH
	MINUS
	MINUS_EQUALS
	MINUS_RIGHT_ANGLE
	ML_BACKQUOTE
	ML_DOUBLE_QUOTE
	ML_SINGLE_QUOTE
	ML_TILDE
	MUT
	NAMESPACE
	NEW
	NEWLINE
	NUMERAL
	OCTAL_NUMBER
	OF
	ON
	OVERRIDE
	OVERWRITE
	PASS
	PERCENT
	PERCENT_EQUALS
	PICK
	PIPE
	PIPE_PIPE
	PIPE_PIPE_EQUALS
	PLUS
	PLUS_EQUALS
	PRIVATE
	PROTECTED
	PROXY
	PUBLIC
	QUESTION
	QUESTION_EQUALS
	QUESTION_DOT
	QUESTION_LEFT_ROUND
	QUESTION_LEFT_SQUARE
	QUESTION_OPERATOR
	QUESTION_QUESTION
	QUESTION_QUESTION_EQUALS
	RADIX_NUMBER
	REGEXP
	REPEAT
	REQUIRE
	REQUIRE_EXTERN
	REQUIRE_IMPORT
	RETURN
	RIGHT_ANGLE
	RIGHT_ANGLE_EQUALS
	RIGHT_ANGLE_RIGHT_ANGLE
	RIGHT_ANGLE_RIGHT_ANGLE_EQUALS
	RIGHT_CURLY
	RIGHT_ROUND
	RIGHT_SQUARE
	SEALED
	SEMICOLON
	SET
	SLASH
	SLASH_DOT
	SLASH_DOT_EQUALS
	SLASH_EQUALS
	SPLIT
	STATIC
	STEP
	STRING
	STRUCT
	SYSTEM
	TEMPLATE_BEGIN
	TEMPLATE_ELEMENT
	TEMPLATE_END
	TEMPLATE_VALUE
	THEN
	THROW
	TILDE
	TILDE_TILDE
	TIMES
	TO
	TO_TILDE
	TRY
	TUPLE
	TYPE
	UNDERSCORE
	UNLESS
	UNTIL
	UP
	VAR
	WHEN
	WHILE
	WITH

	toString(): String { # {{{
		match this {
			RIGHT_CURLY => return '}'
			RIGHT_ROUND => return ')'
			RIGHT_SQUARE => return ']'
			else => return ''
		}
	} # }}}
}

var overhauls = {
	[Token.CLASS_VERSION](data: String): Array<String> => data.split('.')
	[Token.STRING](data: String): String => data.slice(1, -1).replace(/(^|[^\\])\\('|")/g, '$1$2')
}

var regex: Object<RegExp> = {
	binary_number: /^0b[_0-1]+[a-zA-Z]*/
	class_version: /^\d+(\.\d+(\.\d+)?)?/
	decimal_number: /^[0-9][_0-9]*(?:\.[_0-9]+)?(?:[eE][-+]?[_0-9]+)?(?:[a-zA-Z]*)/
	dot_number: /^\.[_0-9]+(?:[eE][-+]?[_0-9]+|[a-zA-Z]*)/
	double_quote: /^([^\\"]|\\.)*\"/
	hex_number: /^0x[_0-9a-fA-F]+(?:\.[_0-9a-fA-F]+[pP][-+]?[_0-9]+)?[a-zA-Z]*/
	macro_value: /^[^#\r\n]+/
	octal_number: /^0o[_0-7]+(?:\.[_0-7]+[pP][-+]?[_0-9]+)?[a-zA-Z]*/
	radix_number: /^(?:[0-9]|[1-2][0-9]|3[0-6])r[_0-9a-zA-Z]+(?:\.[_0-9a-zA-Z]+)?/
	regex: /^=?(?:[^\n\r\*\\\/\[]|\\[^\n\r]|\[(?:[^\n\r\]\\]|\\[^\n\r])*\])(?:[^\n\r\\\/\[]|\\[^\n\r]|\[(?:[^\n\r\]\\]|\\[^\n\r])*\])*\/[gmi]*/
	resource: /(^\s*\r?\n\s*)|(^\})|(^\s*\/\/[^\r\n]*\r?\n\s*)|(^\s*\/\*)|(^\S+)/
	single_quote: /^([^\\']|\\.)*\'/
	template: /^(?:[^`\\\r\n]|\\\\|\\(?!\())+/
}

namespace M {
	export {
		func ASSIGNEMENT_OPERATOR(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			else if c == 35 { // #
				c = that.charAt(1)

				if c == 35 && that.charAt(2) == 61 {
					that.next(3)

					return Token.HASH_HASH_EQUALS
				}
				else if c == 61 {
					that.next(2)

					return Token.HASH_EQUALS
				}
			}
			else if c == 37 { // %
				if that.charAt(1) == 61 {
					that.next(2)

					return Token.PERCENT_EQUALS
				}
			}
			else if c == 38 { // &
				if that.charAt(1) == 38 && that.charAt(2) == 61 {
					that.next(3)

					return Token.AMPERSAND_AMPERSAND_EQUALS
				}
			}
			else if c == 42 { // *
				if that.charAt(1) == 61 {
					that.next(2)

					return Token.ASTERISK_EQUALS
				}
			}
			else if c == 43 { // +
				if that.charAt(1) == 61 {
					that.next(2)

					return Token.PLUS_EQUALS
				}
			}
			else if c == 45 { // -
				if that.charAt(1) == 61 {
					that.next(2)

					return Token.MINUS_EQUALS
				}
			}
			else if c == 47 { // /
				c = that.charAt(1)

				if c == 46 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.SLASH_DOT_EQUALS
					}
				}
				else if c == 61 {
					that.next(2)

					return Token.SLASH_EQUALS
				}
			}
			else if c == 60 { // <
				c = that.charAt(1)

				if c == 45 {
					that.next(2)

					return Token.LEFT_ANGLE_MINUS
				}
				else if c == 60 && that.charAt(2) == 61 {
					that.next(3)

					return Token.LEFT_ANGLE_LEFT_ANGLE_EQUALS
				}
			}
			else if c == 61 { // =
				if that.charAt(1) != 61 & 62 {
					that.next(1)

					return Token.EQUALS
				}
			}
			else if c == 62 { // >
				if that.charAt(1) == 62 && that.charAt(2) == 61 {
					that.next(3)

					return Token.RIGHT_ANGLE_RIGHT_ANGLE_EQUALS
				}
			}
			else if c == 63 { // ?
				c = that.charAt(1)

				if c == 61 {
					that.next(2)

					return Token.QUESTION_EQUALS
				}
				else if c == 63 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.QUESTION_QUESTION_EQUALS
					}
				}
			}
			else if c == 94 { // ^
				if that.charAt(1) == 94 && that.charAt(2) == 61 {
					that.next(3)

					return Token.CARET_CARET_EQUALS
				}
			}
			else if c == 124 { // |
				if that.charAt(1) == 124 && that.charAt(2) == 61 {
					that.next(3)

					return Token.PIPE_PIPE_EQUALS
				}
			}

			return Token.INVALID
		} # }}}

		func BINARY_OPERATOR(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			else if c == 33 { // !
				c = that.charAt(1)

				if c == 35 && that.charAt(2) == 61 {
					that.next(3)

					return Token.EXCLAMATION_HASH_EQUALS
				}
				else if c == 61 {
					that.next(2)

					return Token.EXCLAMATION_EQUALS
				}
				else if c == 63 && that.charAt(2) == 61 {
					that.next(3)

					return Token.EXCLAMATION_QUESTION_EQUALS
				}
				else if c == 126 {
					that.next(2)

					return Token.EXCLAMATION_TILDE
				}
			}
			else if c == 35 { // #
				c = that.charAt(1)

				if c == 35 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.HASH_HASH_EQUALS
					}
					else {
						that.next(2)

						return Token.HASH_HASH
					}
				}
				else if c == 61 {
					that.next(2)

					return Token.HASH_EQUALS
				}
			}
			else if c == 37 { // %
				if that.charAt(1) == 61 {
					that.next(2)

					return Token.PERCENT_EQUALS
				}
				else {
					that.next(1)

					return Token.PERCENT
				}
			}
			else if c == 38 { // &
				c = that.charAt(1)

				if c == 38 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.AMPERSAND_AMPERSAND_EQUALS
					}
					else {
						that.next(2)

						return Token.AMPERSAND_AMPERSAND
					}
				}
			}
			else if c == 42 { // *
				if that.charAt(1) == 61 {
					that.next(2)

					return Token.ASTERISK_EQUALS
				}
				else {
					that.next(1)

					return Token.ASTERISK
				}
			}
			else if c == 43 { // +
				c = that.charAt(1)

				if c == 61 {
					that.next(2)

					return Token.PLUS_EQUALS
				}
				else {
					that.next(1)

					return Token.PLUS
				}
			}
			else if c == 45 { // -
				c = that.charAt(1)

				if c == 61 {
					that.next(2)

					return Token.MINUS_EQUALS
				}
				else if c == 62 {
					that.next(2)

					return Token.MINUS_RIGHT_ANGLE
				}
				else {
					that.next(1)

					return Token.MINUS
				}
			}
			else if c == 47 { // /
				c = that.charAt(1)

				if c == 46 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.SLASH_DOT_EQUALS
					}
					else {
						that.next(2)

						return Token.SLASH_DOT
					}
				}
				else if c == 61 {
					that.next(2)

					return Token.SLASH_EQUALS
				}
				else {
					that.next(1)

					return Token.SLASH
				}
			}
			else if c == 60 { // <
				c = that.charAt(1)

				if c == 45 {
					that.next(2)

					return Token.LEFT_ANGLE_MINUS
				}
				else if c == 60 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.LEFT_ANGLE_LEFT_ANGLE_EQUALS
					}
					else {
						that.next(2)

						return Token.LEFT_ANGLE_LEFT_ANGLE
					}
				}
				else if c == 61 {
					that.next(2)

					return Token.LEFT_ANGLE_EQUALS
				}
				else {
					that.next(1)

					return Token.LEFT_ANGLE
				}
			}
			else if c == 61 { // =
				c = that.charAt(1)

				if c == 61 {
					that.next(2)

					return Token.EQUALS_EQUALS
				}
				else if c != 62 {
					that.next(1)

					return Token.EQUALS
				}
			}
			else if c == 62 { // >
				c = that.charAt(1)

				if c == 61 {
					that.next(2)

					return Token.RIGHT_ANGLE_EQUALS
				}
				else if c == 62 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.RIGHT_ANGLE_RIGHT_ANGLE_EQUALS
					}
					else {
						that.next(2)

						return Token.RIGHT_ANGLE_RIGHT_ANGLE
					}
				}
				else {
					that.next(1)

					return Token.RIGHT_ANGLE
				}
			}
			else if c == 63 { // ?
				c = that.charAt(1)

				if c == 61 {
					that.next(2)

					return Token.QUESTION_EQUALS
				}
				else if c == 63 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.QUESTION_QUESTION_EQUALS
					}
					else {
						that.next(2)

						return Token.QUESTION_QUESTION
					}
				}
			}
			else if c == 94 { // ^
				c = that.charAt(1)

				if c == 94 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.CARET_CARET_EQUALS
					}
					else if that.charAt(2) == 94 {
						that.next(3)

						return Token.CARET_CARET_CARET
					}
					else {
						that.next(2)

						return Token.CARET_CARET
					}
				}
			}
			else if c == 124 { // |
				c = that.charAt(1)

				if c == 124 {
					if that.charAt(2) == 61 {
						that.next(3)

						return Token.PIPE_PIPE_EQUALS
					}
					else {
						that.next(2)

						return Token.PIPE_PIPE
					}
				}
			}
			else if c == 126 { // ~
				if that.charAt(1) == 126 {
					that.next(2)

					return Token.TILDE_TILDE
				}
			}

			return Token.INVALID
		} # }}}

		func DESCRIPTIVE_TYPE(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			// _
			else if c == 95 && !that.isBoundary(1) {
				that.scanIdentifier(false)

				return Token.IDENTIFIER
			}
			// abstract, async
			else if	c == 97 {
				var identifier = that.scanIdentifier(true)
				if identifier == 'bstract' {
					return Token.ABSTRACT
				}
				else if identifier == 'sync' {
					return Token.ASYNC
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// bitmask
			else if c == 98 {
				if that.scanIdentifier(true) == 'itmask' {
					return Token.BITMASK
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// class
			else if c == 99 {
				if that.scanIdentifier(true) == 'lass' {
					return Token.CLASS
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// enum, export
			else if c == 101 {
				var identifier = that.scanIdentifier(true)

				if identifier == 'num' {
					return Token.ENUM
				}
				else if identifier == 'xport' {
					return Token.EXPORT
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// func
			else if c == 102 {
				if that.scanIdentifier(true) == 'unc' {
					return Token.FUNC
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// namespace
			else if c == 110 {
				if that.scanIdentifier(true) == 'amespace' {
					return Token.NAMESPACE
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// sealed, struct, system
			else if c == 115 {
				var identifier = that.scanIdentifier(true)

				if identifier == 'ealed' {
					return Token.SEALED
				}
				else if identifier == 'ystem' {
					return Token.SYSTEM
				}
				else if identifier == 'truct' {
					return Token.STRUCT
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// tuple, type
			else if c == 116 {
				var identifier = that.scanIdentifier(true)

				if identifier == 'uple' {
					return Token.TUPLE
				}
				else if identifier == 'ype' {
					return Token.TYPE
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// var
			else if c == 118 {
				if that.scanIdentifier(true) == 'ar' {
					return Token.VAR
				}
				else {
					return Token.IDENTIFIER
				}
			}
			else if c == 36 || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) {
				that.scanIdentifier(false)

				return Token.IDENTIFIER
			}

			return Token.INVALID
		} # }}}

		func EXPORT_STATEMENT(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			// _
			else if c == 95 && !that.isBoundary(1) {
				that.scanIdentifier(false)

				return Token.IDENTIFIER
			}
			// abstract
			else if c == 97 {
				var identifier = that.scanIdentifier(true)

				if identifier == 'bstract' {
					return Token.ABSTRACT
				}
				else if identifier == 'sync' {
					return Token.ASYNC
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// bitmask
			else if c == 98 {
				var identifier = that.scanIdentifier(true)

				if identifier == 'itmask' {
					return Token.BITMASK
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// class
			else if c == 99 {
				var identifier = that.scanIdentifier(true)

				if identifier == 'lass' {
					return Token.CLASS
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// enum
			else if c == 101 {
				if that.scanIdentifier(true) == 'num' {
					return Token.ENUM
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// final, func
			else if c == 102 {
				var identifier = that.scanIdentifier(true)

				if identifier == 'inal' {
					return Token.FINAL
				}
				else if identifier == 'unc' {
					return Token.FUNC
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// macro
			else if c == 109 {
				if that.scanIdentifier(true) == 'acro' {
					return Token.MACRO
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// namespace
			else if c == 110 {
				if that.scanIdentifier(true) == 'amespace' {
					return Token.NAMESPACE
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// sealed, struct
			else if c == 115 {
				var identifier = that.scanIdentifier(true)

				if identifier == 'ealed' {
					return Token.SEALED
				}
				else if identifier == 'truct' {
					return Token.STRUCT
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// tuple, type
			else if c == 116 {
				var identifier = that.scanIdentifier(true)

				if identifier == 'uple' {
					return Token.TUPLE
				}
				else if identifier == 'ype' {
					return Token.TYPE
				}
				else {
					return Token.IDENTIFIER
				}
			}
			// var
			else if c == 118 {
				if that.scanIdentifier(true) == 'ar' {
					return Token.VAR
				}
				else {
					return Token.IDENTIFIER
				}
			}
			else if c == 36 || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) {
				that.scanIdentifier(false)

				return Token.IDENTIFIER
			}

			return Token.INVALID
		} # }}}

		func JUNCTION_OPERATOR(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			else if c == 38 { // &
				if that.charAt(1) != 38 {
					that.next(1)

					return Token.AMPERSAND
				}
			}
			else if c == 94 { // ^
				if that.charAt(1) != 94 {
					that.next(1)

					return Token.CARET
				}
			}
			else if c == 124 { // |
				if that.charAt(1) != 124 {
					that.next(1)

					return Token.PIPE
				}
			}

			return Token.INVALID
		} # }}}

		func MACRO(that: Scanner, mut index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that._data.charCodeAt(index)

			if c == 13 && that.charAt(1) == 10 {
				that.nextLine(2)

				return Token.NEWLINE
			}
			else if c == 10 | 13 {
				that.nextLine(1)

				return Token.NEWLINE
			}
			else if c == 35 {
				if (c <- that.charAt(1)) == 40 {
					that.next(2)

					return Token.HASH_LEFT_ROUND
				}
				else if c == 97 {
					if that.charAt(2) == 40 {
						that.next(3)

						return Token.HASH_A_LEFT_ROUND
					}
				}
				else if c == 101 {
					if that.charAt(2) == 40 {
						that.next(3)

						return Token.HASH_E_LEFT_ROUND
					}
				}
				else if c == 106 {
					if that.charAt(2) == 40 {
						that.next(3)

						return Token.HASH_J_LEFT_ROUND
					}
				}
				else if c == 115 {
					if that.charAt(2) == 40 {
						that.next(3)

						return Token.HASH_S_LEFT_ROUND
					}
				}
				else if c == 119 {
					if that.charAt(2) == 40 {
						that.next(3)

						return Token.HASH_W_LEFT_ROUND
					}
				}
			}
			else if c == 40 {
				that.next(1)

				return Token.LEFT_ROUND
			}
			else if c == 41 {
				that.next(1)

				return Token.RIGHT_ROUND
			}
			else if c == 123 {
				that.next(1)

				return Token.LEFT_CURLY
			}
			else if c == 125 {
				that.next(1)

				return Token.RIGHT_CURLY
			}

			var from = index

			index += 1

			while index < that._length {
				c = that._data.charCodeAt(index)

				if c == 10 | 13 | 35 | 40 | 41 | 123 | 125 {
					that.next(index - from)

					return Token.INVALID
				}

				index += 1
			}

			if index == from + 1 {
				return Token.EOF
			}
			else {
				that.next(index - from)

				return Token.INVALID
			}
		} # }}}

		func MODULE_STATEMENT(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var mut c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			// disclose
			else if c == 100
			{
				if	that.charAt(1) == 105 &&
					that.charAt(2) == 115 &&
					that.charAt(3) == 99 &&
					that.charAt(4) == 108 &&
					that.charAt(5) == 111 &&
					that.charAt(6) == 115 &&
					that.charAt(7) == 101 &&
					that.isBoundary(8)
				{
					that.next(8)

					return Token.DISCLOSE
				}
			}
			// export, extern, extern|import, extern|require
			else if c == 101
			{
				if	that.charAt(1) == 120 &&
					that.charAt(2) == 112 &&
					that.charAt(3) == 111 &&
					that.charAt(4) == 114 &&
					that.charAt(5) == 116 &&
					that.isBoundary(6)
				{
					that.next(6)

					return Token.EXPORT
				}
				else if that.charAt(1) == 120 &&
					that.charAt(2) == 116 &&
					that.charAt(3) == 101 &&
					that.charAt(4) == 114 &&
					that.charAt(5) == 110
				{
					if	that.charAt(6) == 124
					{
						if	that.charAt(7) == 105 &&
							that.charAt(8) == 109 &&
							that.charAt(9) == 112 &&
							that.charAt(10) == 111 &&
							that.charAt(11) == 114 &&
							that.charAt(12) == 116 &&
							that.isBoundary(13)
						{
							that.next(13)

							return Token.EXTERN_IMPORT
						}
						else if	that.charAt(7) == 114 &&
								that.charAt(8) == 101 &&
								that.charAt(9) == 113 &&
								that.charAt(10) == 117 &&
								that.charAt(11) == 105 &&
								that.charAt(12) == 114 &&
								that.charAt(13) == 101 &&
								that.isBoundary(14)
						{
							that.next(14)

							return Token.EXTERN_REQUIRE
						}
					}
					else if that.isBoundary(6)
					{
						that.next(6)

						return Token.EXTERN
					}
				}
			}
			// import, include, include again
			else if c == 105
			{
				if	that.charAt(1) == 110 &&
					that.charAt(2) == 99 &&
					that.charAt(3) == 108 &&
					that.charAt(4) == 117 &&
					that.charAt(5) == 100 &&
					that.charAt(6) == 101
				{
					if	that.charAt(7) == 32 &&
						that.charAt(8) == 97 &&
						that.charAt(9) == 103 &&
						that.charAt(10) == 97 &&
						that.charAt(11) == 105 &&
						that.charAt(12) == 110 &&
						that.isBoundary(13)
					{
						that.next(13)

						return Token.INCLUDE_AGAIN
					}
					else if that.isBoundary(7) {
						that.next(7)

						return Token.INCLUDE
					}
				}
			}
			// require, require|extern, require|import
			else if c == 114
			{
				if	that.charAt(1) == 101 &&
					that.charAt(2) == 113 &&
					that.charAt(3) == 117 &&
					that.charAt(4) == 105 &&
					that.charAt(5) == 114 &&
					that.charAt(6) == 101
				{
					if that.charAt(7) == 124
					{
						if	that.charAt(8) == 101 &&
							that.charAt(9) == 120 &&
							that.charAt(10) == 116 &&
							that.charAt(11) == 101 &&
							that.charAt(12) == 114 &&
							that.charAt(13) == 110 &&
							that.isBoundary(14)
						{
							that.next(14)

							return Token.REQUIRE_EXTERN
						}
						else if that.charAt(8) == 105 &&
							that.charAt(9) == 109 &&
							that.charAt(10) == 112 &&
							that.charAt(11) == 111 &&
							that.charAt(12) == 114 &&
							that.charAt(13) == 116 &&
							that.isBoundary(14)
						{
							that.next(14)

							return Token.REQUIRE_IMPORT
						}
					}
					else if that.isBoundary(7)
					{
						that.next(7)

						return Token.REQUIRE
					}
				}
			}

			return Token.INVALID
		} # }}}

		func NUMBER(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			else if c == 46 {
				var dyn substr = that._data.substr(that._index)

				if match ?= regex.dot_number.exec(substr) {
					that.next(match[0].length)

					return Token.DECIMAL_NUMBER
				}
			}
			else if c >= 48 && c <= 57 { // 0 - 9
				var dyn substr = that._data.substr(that._index)

				if match ?= regex.binary_number.exec(substr) {
					that.next(match[0].length)

					return Token.BINARY_NUMBER
				}
				else if match ?= regex.octal_number.exec(substr) {
					that.next(match[0].length)

					return Token.OCTAL_NUMBER
				}
				else if match ?= regex.hex_number.exec(substr) {
					that.next(match[0].length)

					return Token.HEX_NUMBER
				}
				else if match ?= regex.radix_number.exec(substr) {
					that.next(match[0].length)

					return Token.RADIX_NUMBER
				}
				else if match ?= regex.decimal_number.exec(substr) {
					that.next(match[0].length)

					return Token.DECIMAL_NUMBER
				}
			}

			return Token.INVALID
		} # }}}

		func OPERAND(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			else if c == 34 { // "
				if that.charAt(1) == 34 && that.charAt(2) == 34 {
					that.next(3)

					return Token.ML_DOUBLE_QUOTE
				}
				else if var match ?= regex.double_quote.exec(that.substringAt(1)) {
					that.next(match[0].length + 1)

					return Token.STRING
				}
			}
			else if c == 36 { // $
				that.scanIdentifier(false)

				return Token.IDENTIFIER
			}
			else if c == 39 { // '
				if that.charAt(1) == 39 && that.charAt(2) == 39 {
					that.next(3)

					return Token.ML_SINGLE_QUOTE
				}
				else if match ?= regex.single_quote.exec(that.substringAt(1)) {
					that.next(match[0].length + 1)

					return Token.STRING
				}
			}
			else if c == 40 { // (
				that.next(1)

				return Token.LEFT_ROUND
			}
			else if c == 47 { // /
				if match ?= regex.regex.exec(that.substringAt(1)) {
					that.next(match[0].length + 1)

					return Token.REGEXP
				}
			}
			else if c == 64 { // @
				if fMode == FunctionMode.Method {
					that.next(1)

					return Token.AT
				}
			}
			else if c >= 65 && c <= 90 { // A-Z
				that.scanIdentifier(false)

				return Token.IDENTIFIER
			}
			else if c == 91 { // [
				that.next(1)

				return Token.LEFT_SQUARE
			}
			else if c == 95 && !that.isBoundary(1) { // _
				that.scanIdentifier(false)

				return Token.IDENTIFIER
			}
			else if c == 96 { // `
				if that.charAt(1) == 96 && that.charAt(2) == 96 {
					that.next(3)

					return Token.ML_BACKQUOTE
				}
				else {
					that.next(1)

					return Token.TEMPLATE_BEGIN
				}
			}
			else if c == 110 { // n
				if that.scanIdentifier(true) == 'ew' {
					return Token.NEW
				}
				else {
					return Token.IDENTIFIER
				}
			}
			else if c >= 97 && c <= 122 { // a-z
				that.scanIdentifier(false)

				return Token.IDENTIFIER
			}
			else if c == 123 { // {
				that.next(1)

				return Token.LEFT_CURLY
			}
			else if c == 126 { // ~
				if that.charAt(1) == 126 && that.charAt(2) == 126 {
					that.next(3)

					return Token.ML_TILDE
				}
			}

			return Token.INVALID
		} # }}}

		func OPERAND_JUNCTION(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn p = that._data.charCodeAt(index - 1)
			var dyn c = that._data.charCodeAt(index)

			if p == 9 || p == 32 {
				return Token.INVALID
			}
			else if c == 13 && that.charAt(1) == 10 {
				that.nextLine(2)

				return Token.NEWLINE
			}
			else if c == 10 || c == 13 {
				that.nextLine(1)

				return Token.NEWLINE
			}
			else if c == 40 { // (
				that.next(1)

				return Token.LEFT_ROUND
			}
			else if c == 42 { // *
				if that.charAt(2) == 40 {
					c = that.charAt(1)

					if c == 36 {
						that.next(3)

						return Token.ASTERISK_DOLLAR_LEFT_ROUND
					}
				}
			}
			else if c == 46 { // .
				if that.charAt(1) != 46 & 9 & 32 {
					that.next(1)

					return Token.DOT
				}
				else if that.charAt(1) == 46 && that.charAt(2) != 46 & 9 & 32 {
					that.next(2)

					return Token.DOT_DOT
				}
			}
			else if c == 58 { // :
				c = that.charAt(1)
				var c2 = that.charAt(2)

				if c == 33 && c2 != 9 && c2 != 32 {
					that.next(2)

					return Token.COLON_EXCLAMATION
				}
				else if c == 63 && c2 != 9 && c2 != 32 {
					that.next(2)

					return Token.COLON_QUESTION
				}
				else if c != 61 && c != 9 && c != 32 {
					that.next(1)

					return Token.COLON
				}
			}
			else if c == 63 { // ?
				c = that.charAt(1)

				if c == 40 {
					that.next(2)

					return Token.QUESTION_LEFT_ROUND
				}
				else if c == 46 && !(that.charAt(2) == 9 | 32) {
					that.next(2)

					return Token.QUESTION_DOT
				}
				else if c == 91 {
					that.next(2)

					return Token.QUESTION_LEFT_SQUARE
				}
			}
			else if c == 91 { // [
				that.next(1)

				return Token.LEFT_SQUARE
			}
			else if c == 94 { // ^
				if that.charAt(2) == 40 {
					c = that.charAt(1)

					if c == 36 {
						that.next(3)

						return Token.CARET_DOLLAR_LEFT_ROUND
					}
					else if c == 94 {
						that.next(3)

						return Token.CARET_CARET_LEFT_ROUND
					}
				}
			}
			else if c == 96 { // `
				that.next(1)

				return Token.TEMPLATE_BEGIN
			}

			return Token.INVALID
		} # }}}

		func POSTFIX_OPERATOR(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn p = that._data.charCodeAt(index - 1)
			var dyn c = that._data.charCodeAt(index)

			if p == 9 || p == 32 {
				return Token.INVALID
			}
			else if c == 33 { // !
				if (c <- that.charAt(1)) == 33 {
					that.next(2)

					return Token.EXCLAMATION_EXCLAMATION
				}
				else if c == 63 {
					that.next(2)

					return Token.EXCLAMATION_QUESTION
				}
			}

			return Token.INVALID
		} # }}}

		func PREFIX_OPERATOR(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			else if c == 33 { // !
				if !((c <- that.charAt(1)) == 61 || (c == 63 && that.charAt(2) == 61) || c == 9 | 32) {
					that.next(1)

					return Token.EXCLAMATION
				}
			}
			else if c == 35 { // #
				c = that.charAt(1)

				if c != 35 & 61 {
					that.next(1)

					return Token.HASH
				}
			}
			else if c == 45 { // -
				c = that.charAt(1)

				if c != 61 {
					that.next(1)

					return Token.MINUS
				}
			}
			else if c == 46 { // .
				if that.charAt(1) == 46 && that.charAt(2) == 46 && that.charAt(3) != 9 & 32 {
					that.next(3)

					return Token.DOT_DOT_DOT
				}
				else if eMode ~~ ExpressionMode.ImplicitMember {
					that.next(1)

					return Token.DOT
				}
			}
			else if c == 63 { // ?
				if that.charAt(1) != 9 & 32 {
					that.next(1)

					return Token.QUESTION
				}
			}

			return Token.INVALID
		} # }}}

		func STATEMENT(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			// abstract, async
			else if	c == 97
			{
				if	that.charAt(1) == 98 &&
					that.charAt(2) == 115 &&
					that.charAt(3) == 116 &&
					that.charAt(4) == 114 &&
					that.charAt(5) == 97 &&
					that.charAt(6) == 99 &&
					that.charAt(7) == 116 &&
					that.isBoundary(8)
				{
					that.next(8)

					return Token.ABSTRACT
				}
				else if that.charAt(1) == 115 &&
						that.charAt(2) == 121 &&
						that.charAt(3) == 110 &&
						that.charAt(4) == 99 &&
						that.isBoundary(5)
				{
					that.next(5)

					return Token.ASYNC
				}
				else if that.charAt(1) == 117 &&
						that.charAt(2) == 116 &&
						that.charAt(3) == 111 &&
						that.isBoundary(4)
				{
					that.next(4)

					return Token.AUTO
				}
			}
			// bitmask, block, break
			else if	c == 98
			{
				if	that.charAt(1) == 105 &&
					that.charAt(2) == 116 &&
					that.charAt(3) == 109 &&
					that.charAt(4) == 97 &&
					that.charAt(5) == 115 &&
					that.charAt(6) == 107 &&
					that.isBoundary(7)
				{
					that.next(7)

					return Token.BITMASK
				}
				else if	that.charAt(1) == 108 &&
						that.charAt(2) == 111 &&
						that.charAt(3) == 99 &&
						that.charAt(4) == 107 &&
						that.isBoundary(5)
				{
					that.next(5)

					return Token.BLOCK
				}
				else if	that.charAt(1) == 114 &&
						that.charAt(2) == 101 &&
						that.charAt(3) == 97 &&
						that.charAt(4) == 107 &&
						that.isBoundary(5)
				{
					that.next(5)

					return Token.BREAK
				}
			}
			// class, continue
			else if c == 99
			{
				if	that.charAt(1) == 108 &&
					that.charAt(2) == 97 &&
					that.charAt(3) == 115 &&
					that.charAt(4) == 115 &&
					that.isBoundary(5)
				{
					that.next(5)

					return Token.CLASS
				}
				else if	that.charAt(1) == 111 &&
					that.charAt(2) == 110 &&
					that.charAt(3) == 116 &&
					that.charAt(4) == 105 &&
					that.charAt(5) == 110 &&
					that.charAt(6) == 117 &&
					that.charAt(7) == 101 &&
					that.isBoundary(8)
				{
					that.next(8)

					return Token.CONTINUE
				}
			}
			// do, drop
			else if	c == 100
			{
				if 	that.charAt(1) == 111 &&
					that.isBoundary(2)
				{
					that.next(2)

					return Token.DO
				}
				else if	that.charAt(1) == 114 &&
					that.charAt(2) == 111 &&
					that.charAt(3) == 112 &&
					that.isBoundary(4)
				{
					that.next(4)

					return Token.DROP
				}
			}
			// enum
			else if c == 101
			{
				if	that.charAt(1) == 110 &&
					that.charAt(2) == 117 &&
					that.charAt(3) == 109 &&
					that.isBoundary(4)
				{
					that.next(4)

					return Token.ENUM
				}
			}
			// fallthrough, final, for, func
			else if c == 102
			{
				if	that.charAt(1) == 111 &&
					that.charAt(2) == 114 &&
					that.isBoundary(3)
				{
					that.next(3)

					return Token.FOR
				}
				else if that.charAt(1) == 117 &&
					that.charAt(2) == 110 &&
					that.charAt(3) == 99 &&
					that.isBoundary(4)
				{
					that.next(4)

					return Token.FUNC
				}
				else if that.charAt(1) == 105 &&
					that.charAt(2) == 110 &&
					that.charAt(3) == 97 &&
					that.charAt(4) == 108 &&
					that.isBoundary(5)
				{
					that.next(5)

					return Token.FINAL
				}
				else if that.charAt(1) == 97 &&
					that.charAt(2) == 108 &&
					that.charAt(3) == 108 &&
					that.charAt(4) == 116 &&
					that.charAt(5) == 104 &&
					that.charAt(6) == 114 &&
					that.charAt(7) == 111 &&
					that.charAt(8) == 117 &&
					that.charAt(9) == 103 &&
					that.charAt(10) == 104 &&
					that.isBoundary(11)
				{
					that.next(11)

					return Token.FALLTHROUGH
				}
			}
			// if, impl, import
			else if c == 105
			{
				if	that.charAt(1) == 102 &&
					that.isBoundary(2)
				{
					that.next(2)

					return Token.IF
				}
				else if that.charAt(1) == 109 &&
					that.charAt(2) == 112 &&
					that.charAt(3) == 108 &&
					that.isBoundary(4)
				{
					that.next(4)

					return Token.IMPL
				}
				else if that.charAt(1) == 109 &&
					that.charAt(2) == 112 &&
					that.charAt(3) == 111 &&
					that.charAt(4) == 114 &&
					that.charAt(5) == 116 &&
					that.isBoundary(6)
				{
					that.next(6)

					return Token.IMPORT
				}
			}
			// lateinit
			else if c == 108
			{
				if	that.charAt(1) == 97 &&
					that.charAt(2) == 116 &&
					that.charAt(3) == 101 &&
					that.charAt(4) == 105 &&
					that.charAt(5) == 110 &&
					that.charAt(6) == 105 &&
					that.charAt(7) == 116 &&
					that.isBoundary(8)
				{
					that.next(8)

					return Token.LATEINIT
				}
			}
			// macro, match
			else if c == 109
			{
				if	that.charAt(1) == 97 &&
					that.charAt(2) == 99 &&
					that.charAt(3) == 114 &&
					that.charAt(4) == 111 &&
					that.isBoundary(5)
				{
					that.next(5)

					return Token.MACRO
				}
				else if that.charAt(1) == 97 &&
					that.charAt(2) == 116 &&
					that.charAt(3) == 99 &&
					that.charAt(4) == 104 &&
					that.isBoundary(5)
				{
					that.next(5)

					return Token.MATCH
				}
			}
			// namespace
			else if c == 110
			{
				if	that.charAt(1) == 97 &&
					that.charAt(2) == 109 &&
					that.charAt(3) == 101 &&
					that.charAt(4) == 115 &&
					that.charAt(5) == 112 &&
					that.charAt(6) == 97 &&
					that.charAt(7) == 99 &&
					that.charAt(8) == 101 &&
					that.isBoundary(9)
				{
					that.next(9)

					return Token.NAMESPACE
				}
			}
			// pass, pick
			else if c == 112
			{
				if	that.charAt(1) == 97 &&
					that.charAt(2) == 115 &&
					that.charAt(3) == 115 &&
					that.isBoundary(4)
				{
					that.next(4)

					return Token.PASS
				}
				else if pMode ~~ ParserMode.InlineStatement &&
					that.charAt(1) == 105 &&
					that.charAt(2) == 99 &&
					that.charAt(3) == 107 &&
					that.isBoundary(4)
				{
					that.next(4)

					return Token.PICK
				}
			}
			// repeat, return
			else if c == 114
			{
				if	that.charAt(1) == 101 &&
					that.charAt(2) == 112 &&
					that.charAt(3) == 101 &&
					that.charAt(4) == 97 &&
					that.charAt(5) == 116 &&
					that.isBoundary(6)
				{
					that.next(6)

					return Token.REPEAT
				}
				else if	that.charAt(1) == 101 &&
					that.charAt(2) == 116 &&
					that.charAt(3) == 117 &&
					that.charAt(4) == 114 &&
					that.charAt(5) == 110 &&
					that.isBoundary(6)
				{
					that.next(6)

					return Token.RETURN
				}
			}
			// sealed, struct
			else if c == 115
			{
				if	that.charAt(1) == 101 &&
					that.charAt(2) == 97 &&
					that.charAt(3) == 108 &&
					that.charAt(4) == 101 &&
					that.charAt(5) == 100 &&
					that.isBoundary(6)
				{
					that.next(6)

					return Token.SEALED
				}
				else if that.charAt(1) == 116 &&
					that.charAt(2) == 114 &&
					that.charAt(3) == 117 &&
					that.charAt(4) == 99 &&
					that.charAt(5) == 116 &&
					that.isBoundary(6)
				{
					that.next(6)

					return Token.STRUCT
				}
			}
			// throw, try, tuple, type
			else if c == 116
			{
				if	that.charAt(1) == 104 &&
					that.charAt(2) == 114 &&
					that.charAt(3) == 111 &&
					that.charAt(4) == 119 &&
					that.isBoundary(5)
				{
					that.next(5)

					return Token.THROW
				}
				else if that.charAt(1) == 114 &&
					that.charAt(2) == 121 &&
					that.isBoundary(3)
				{
					that.next(3)

					return Token.TRY
				}
				else if	that.charAt(1) == 117 &&
					that.charAt(2) == 112 &&
					that.charAt(3) == 108 &&
					that.charAt(4) == 101 &&
					that.isBoundary(5)
				{
					that.next(5)

					return Token.TUPLE
				}
				else if that.charAt(1) == 121 &&
					that.charAt(2) == 112 &&
					that.charAt(3) == 101 &&
					that.isBoundary(4)
				{
					that.next(4)

					return Token.TYPE
				}
			}
			// unless, until
			else if c == 117
			{
				if	that.charAt(1) == 110 &&
					that.charAt(2) == 108 &&
					that.charAt(3) == 101 &&
					that.charAt(4) == 115 &&
					that.charAt(5) == 115 &&
					that.isBoundary(6)
				{
					that.next(6)

					return Token.UNLESS
				}
				else if	that.charAt(1) == 110 &&
					that.charAt(2) == 116 &&
					that.charAt(3) == 105 &&
					that.charAt(4) == 108 &&
					that.isBoundary(5)
				{
					that.next(5)

					return Token.UNTIL
				}
			}
			// var
			else if c == 118
			{
				if	that.charAt(1) == 97 &&
					that.charAt(2) == 114 &&
					that.isBoundary(3)
				{
					that.next(3)

					return Token.VAR
				}
			}
			// while, with
			else if c == 119
			{
				if	that.charAt(1) == 104 &&
					that.charAt(2) == 105 &&
					that.charAt(3) == 108 &&
					that.charAt(4) == 101 &&
					that.isBoundary(5)
				{
					that.next(5)

					return Token.WHILE
				}
				else if	that.charAt(1) == 105 &&
					that.charAt(2) == 116 &&
					that.charAt(3) == 104 &&
					that.isBoundary(4)
				{
					that.next(4)

					return Token.WITH
				}
			}

			return Token.INVALID
		} # }}}

		func TEMPLATE(that: Scanner, mut index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that._data.charCodeAt(index)

			if c == 92 && that._data.charCodeAt(index + 1) == 40 { // \(
				that.next(2)

				return Token.TEMPLATE_ELEMENT
			}
			else if c == 96 { // )
				return Token.TEMPLATE_END
			}
			else if match ?= regex.template.exec(that._data.substr(index)) {
				that.next(match[0].length)

				return Token.TEMPLATE_VALUE
			}

			return Token.INVALID
		} # }}}

		func TYPE_OPERATOR(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
			var dyn c = that.skip(index)

			if c == -1 {
				return Token.EOF
			}
			// as
			else if c == 97
			{
				if that.charAt(1) == 115 {
					if that.charAt(2) == 33 && that.isBoundary(3) {
						that.next(3)

						return Token.AS_EXCLAMATION
					}
					else if that.charAt(2) == 63 && that.isBoundary(3) {
						that.next(3)

						return Token.AS_QUESTION
					}
					else if that.isBoundary(2) {
						that.next(2)

						return Token.AS
					}
				}
			}
			// is, is not
			else if c == 105
			{
				if that.charAt(1) == 115 {
					if that.charAt(2) == 9 | 32 {
						if	that.charAt(3) == 110 &&
							that.charAt(4) == 111 &&
							that.charAt(5) == 116 &&
							that.isBoundary(6)
						{
							that.next(6)

							return Token.IS_NOT
						}

						that.next(2)

						return Token.IS
					}
					else if that.isBoundary(2) {
						that.next(2)

						return Token.IS
					}
				}
			}

			return Token.INVALID
		} # }}}
	}
}

var recognize = {
	`\(Token.ABSTRACT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 97 &&
			that.charAt(1) == 98 &&
			that.charAt(2) == 115 &&
			that.charAt(3) == 116 &&
			that.charAt(4) == 114 &&
			that.charAt(5) == 97 &&
			that.charAt(6) == 99 &&
			that.charAt(7) == 116 &&
			that.isBoundary(8)
		{
			return that.next(8)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.AMPERSAND)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 38 && that.charAt(1) != 61 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.AMPERSAND_AMPERSAND)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 38 && that.charAt(1) == 38 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ASTERISK)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 42 && that.charAt(1) != 42 & 36 & 61 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.AS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 97 &&
			that.charAt(1) == 115 &&
			that.isBoundary(2)
		{
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ASYNC)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 97 &&
			that.charAt(1) == 115 &&
			that.charAt(2) == 121 &&
			that.charAt(3) == 110 &&
			that.charAt(4) == 99 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.AT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 64 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ATTRIBUTE_IDENTIFIER)`(that: Scanner, mut c: Number): Boolean { # {{{
		if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) {
			var dyn index = that._index

			var dyn c
			while index < that._length &&
			(
				(c <- that._data.charCodeAt(index)) == 45 ||
				c == 46 ||
				(c >= 48 && c <= 57) ||
				(c >= 65 && c <= 90) ||
				c == 95 ||
				(c >= 97 && c <= 122)
			) {
				index += 1
			}

			that.next(index - that._index)

			return true
		}
		else {
			return false
		}
	} # }}}
	`\(Token.AUTO)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 97 &&
			that.charAt(1) == 117 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 111 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else
		{
			return false
		}
	} # }}}
	`\(Token.AWAIT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 97 &&
			that.charAt(1) == 119 &&
			that.charAt(2) == 97 &&
			that.charAt(3) == 105 &&
			that.charAt(4) == 116 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.BACKSLASH)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 92 {
			c = that.charAt(1)

			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.BREAK)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 98 &&
			that.charAt(1) == 114 &&
			that.charAt(2) == 101 &&
			that.charAt(3) == 97 &&
			that.charAt(4) == 107 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.BUT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 98 &&
			that.charAt(1) == 117 &&
			that.charAt(2) == 116 &&
			that.isBoundary(3)
		{
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.CARET)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 94 && that.charAt(1) != 61 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.CARET_CARET)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 94 && that.charAt(1) == 94 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.CATCH)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 99 &&
			that.charAt(1) == 97 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 99 &&
			that.charAt(4) == 104 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.CLASS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 99 &&
			that.charAt(1) == 108 &&
			that.charAt(2) == 97 &&
			that.charAt(3) == 115 &&
			that.charAt(4) == 115 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.CLASS_VERSION)`(that: Scanner, mut c: Number): Boolean { # {{{
		if match ?= regex.class_version.exec(that.substringAt(0)) {
			return that.next(match[0].length)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.COLON)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 58 {
			c = that.charAt(1)

			return c == 58 || c == 61 ? false : that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.COMMA)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 44 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.CONTINUE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 99 &&
			that.charAt(1) == 111 &&
			that.charAt(2) == 110 &&
			that.charAt(3) == 116 &&
			that.charAt(4) == 105 &&
			that.charAt(5) == 110 &&
			that.charAt(6) == 117 &&
			that.charAt(7) == 101 &&
			that.isBoundary(8)
		{
			return that.next(8)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.DOT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 46 && that.charAt(1) != 46 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.DOT_DOT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 46 && that.charAt(1) == 46 && that.charAt(2) != 46 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.DOT_DOT_DOT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 46 && that.charAt(1) == 46 && that.charAt(2) == 46 {
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.DOWN)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 100 &&
			that.charAt(1) == 111 &&
			that.charAt(2) == 119 &&
			that.charAt(3) == 110 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.DYN)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 100 &&
			that.charAt(1) == 121 &&
			that.charAt(2) == 110 &&
			that.isBoundary(3)
		{
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ELSE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 101 &&
			that.charAt(1) == 108 &&
			that.charAt(2) == 115 &&
			that.charAt(3) == 101 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ELSE_IF)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 101 &&
			that.charAt(1) == 108 &&
			that.charAt(2) == 115 &&
			that.charAt(3) == 101 &&
			that.charAt(4) == 32 &&
			that.charAt(5) == 105 &&
			that.charAt(6) == 102 &&
			that.isBoundary(7)
		{
			return that.next(7)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ENUM)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 101 &&
			that.charAt(1) == 110 &&
			that.charAt(2) == 117 &&
			that.charAt(3) == 109 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.EQUALS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 61 && that.charAt(1) != 61 & 62 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.EQUALS_RIGHT_ANGLE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 61 && that.charAt(1) == 62{
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.EXCLAMATION)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 33 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.EXTENDS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 101 &&
			that.charAt(1) == 120 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 101 &&
			that.charAt(4) == 110 &&
			that.charAt(5) == 100 &&
			that.charAt(6) == 115 &&
			that.isBoundary(7)
		{
			return that.next(7)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.FINAL)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 102 &&
			that.charAt(1) == 105 &&
			that.charAt(2) == 110 &&
			that.charAt(3) == 97 &&
			that.charAt(4) == 108 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.FINALLY)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 102 &&
			that.charAt(1) == 105 &&
			that.charAt(2) == 110 &&
			that.charAt(3) == 97 &&
			that.charAt(4) == 108 &&
			that.charAt(5) == 108 &&
			that.charAt(6) == 121 &&
			that.isBoundary(7)
		{
			return that.next(7)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.FOR)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 102 &&
			that.charAt(1) == 111 &&
			that.charAt(2) == 114 &&
			that.isBoundary(3)
		{
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.FROM)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 102 &&
			that.charAt(1) == 114 &&
			that.charAt(2) == 111 &&
			that.charAt(3) == 109 &&
			that.charAt(4) != 126 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.FROM_TILDE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 102 &&
			that.charAt(1) == 114 &&
			that.charAt(2) == 111 &&
			that.charAt(3) == 109 &&
			that.charAt(4) == 126 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.FUNC)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 102 &&
			that.charAt(1) == 117 &&
			that.charAt(2) == 110 &&
			that.charAt(3) == 99 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.GET)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 103 &&
			that.charAt(1) == 101 &&
			that.charAt(2) == 116 &&
			that.isBoundary(3)
		{
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.HASH)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 35 && that.charAt(1) != 33 & 35 & 61 & 91 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.HASH_EQUALS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 35 && that.charAt(1) == 61 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.HASH_EXCLAMATION)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 35 && that.charAt(1) == 33 && that.charAt(2) != 91 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.HASH_EXCLAMATION_LEFT_SQUARE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 35 && that.charAt(1) == 33 && that.charAt(2) == 91 {
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.HASH_HASH_EQUALS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 35 && that.charAt(1) == 35 && that.charAt(2) == 61 {
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.HASH_LEFT_SQUARE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 35 && that.charAt(1) == 91 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.IDENTIFIER)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 36 || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) {
			that.scanIdentifier(false)

			return true
		}
		else if c == 95 && !that.isBoundary(1) {
			that.scanIdentifier(false)

			return true
		}
		else {
			return false
		}
	} # }}}
	`\(Token.IF)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 105 &&
			that.charAt(1) == 102 &&
			that.isBoundary(2)
		{
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.IN)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 105 &&
			that.charAt(1) == 110 &&
			that.isBoundary(2)
		{
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.INTERNAL)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 105 &&
			that.charAt(1) == 110 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 101 &&
			that.charAt(4) == 114 &&
			that.charAt(5) == 110 &&
			that.charAt(6) == 97 &&
			that.charAt(7) == 108 &&
			that.isBoundary(8)
		{
			return that.next(8)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.IS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 105 &&
			that.charAt(1) == 115 &&
			that.isBoundary(2)
		{
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.LATE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 108 &&
			that.charAt(1) == 97 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 101 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.LATEINIT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 108 &&
			that.charAt(1) == 97 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 101 &&
			that.charAt(4) == 105 &&
			that.charAt(5) == 110 &&
			that.charAt(6) == 105 &&
			that.charAt(7) == 116 &&
			that.isBoundary(8)
		{
			return that.next(8)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.LEFT_ANGLE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 60 {
			c = that.charAt(1)

			return c == 60 || c == 61 ? false : that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.LEFT_CURLY)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 123 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.LEFT_ROUND)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 40 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.LEFT_SQUARE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 91 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.MACRO)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 109 &&
			that.charAt(1) == 97 &&
			that.charAt(2) == 99 &&
			that.charAt(3) == 114 &&
			that.charAt(4) == 111 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.MATCH)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 109 &&
			that.charAt(1) == 97 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 99 &&
			that.charAt(4) == 104 &&
			that.isSpace(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.MINUS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 45 && that.charAt(1) != 61 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ML_BACKQUOTE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 96 && that.charAt(1) == 96 && that.charAt(2) == 96 {
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ML_DOUBLE_QUOTE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 34 && that.charAt(1) == 34 && that.charAt(2) == 34 {
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ML_SINGLE_QUOTE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 39 && that.charAt(1) == 39 && that.charAt(2) == 39 {
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ML_TILDE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 126 && that.charAt(1) == 126 && that.charAt(2) == 126 {
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.MUT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 109 &&
			that.charAt(1) == 117 &&
			that.charAt(2) == 116 &&
			that.isBoundary(3)
		{
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.NEWLINE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 13 && that.charAt(1) == 10 {
			return that.nextLine(2)
		}
		else if c == 10 || c == 13 {
			return that.nextLine(1)
		}

		return false
	} # }}}
	`\(Token.NUMERAL)`(that: Scanner, mut c: Number): Boolean { # {{{
		if 48 <= c <= 57 {
			var mut i = 1

			while 48 <= that.charAt(i) <= 57 {
				i += 1
			}

			if that.isBoundary(i) {
				return that.next(i)
			}
		}

		return false
	} # }}}
	`\(Token.OF)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 111 &&
			that.charAt(1) == 102 &&
			that.isBoundary(2)
		{
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.ON)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 111 &&
			that.charAt(1) == 110 &&
			that.isBoundary(2)
		{
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.OVERRIDE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 111 &&
			that.charAt(1) == 118 &&
			that.charAt(2) == 101 &&
			that.charAt(3) == 114 &&
			that.charAt(4) == 114 &&
			that.charAt(5) == 105 &&
			that.charAt(6) == 100 &&
			that.charAt(7) == 101 &&
			that.isBoundary(8)
		{
			return that.next(8)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.OVERWRITE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 111 &&
			that.charAt(1) == 118 &&
			that.charAt(2) == 101 &&
			that.charAt(3) == 114 &&
			that.charAt(4) == 119 &&
			that.charAt(5) == 114 &&
			that.charAt(6) == 105 &&
			that.charAt(7) == 116 &&
			that.charAt(8) == 101 &&
			that.isBoundary(9)
		{
			return that.next(9)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.PASS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 112 &&
			that.charAt(1) == 97 &&
			that.charAt(2) == 115 &&
			that.charAt(3) == 115 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.PERCENT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 37 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.PIPE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 124 && that.charAt(1) != 61 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.PIPE_PIPE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 124 && that.charAt(1) == 124 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.PRIVATE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 112 &&
			that.charAt(1) == 114 &&
			that.charAt(2) == 105 &&
			that.charAt(3) == 118 &&
			that.charAt(4) == 97 &&
			that.charAt(5) == 116 &&
			that.charAt(6) == 101 &&
			that.isBoundary(7)
		{
			return that.next(7)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.PROTECTED)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 112 &&
			that.charAt(1) == 114 &&
			that.charAt(2) == 111 &&
			that.charAt(3) == 116 &&
			that.charAt(4) == 101 &&
			that.charAt(5) == 99 &&
			that.charAt(6) == 116 &&
			that.charAt(7) == 101 &&
			that.charAt(8) == 100 &&
			that.isBoundary(9)
		{
			return that.next(9)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.PROXY)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 112 &&
			that.charAt(1) == 114 &&
			that.charAt(2) == 111 &&
			that.charAt(3) == 120 &&
			that.charAt(4) == 121 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.PUBLIC)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 112 &&
			that.charAt(1) == 117 &&
			that.charAt(2) == 98 &&
			that.charAt(3) == 108 &&
			that.charAt(4) == 105 &&
			that.charAt(5) == 99 &&
			that.isBoundary(6)
		{
			return that.next(6)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.QUESTION)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 63 && that.charAt(1) != 61 & 63 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.QUESTION_EQUALS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 63 && that.charAt(1) == 61 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.QUESTION_OPERATOR)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 63 {
			return that.charAt(1) == 40 | 46 | 61 | 63 | 91 ? false : that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.QUESTION_QUESTION)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 63 && that.charAt(1) == 63 && that.charAt(2) != 61 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.QUESTION_QUESTION_EQUALS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 63 && that.charAt(1) == 63 && that.charAt(2) == 61 {
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.REPEAT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 114 &&
			that.charAt(1) == 101 &&
			that.charAt(2) == 112 &&
			that.charAt(3) == 101 &&
			that.charAt(4) == 97 &&
			that.charAt(5) == 116 &&
			that.isBoundary(6)
		{
			return that.next(6)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.RETURN)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 114 &&
			that.charAt(1) == 101 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 117 &&
			that.charAt(4) == 114 &&
			that.charAt(5) == 110 &&
			that.isBoundary(6)
		{
			return that.next(6)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.RIGHT_ANGLE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 62 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.RIGHT_CURLY)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 125 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.RIGHT_ROUND)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 41 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.RIGHT_SQUARE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 93 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.SEMICOLON)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 59 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.SET)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 115 &&
			that.charAt(1) == 101 &&
			that.charAt(2) == 116 &&
			that.isBoundary(3)
		{
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.SPLIT)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 115 &&
			that.charAt(1) == 112 &&
			that.charAt(2) == 108 &&
			that.charAt(3) == 105 &&
			that.charAt(4) == 116 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.STEP)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 115 &&
			that.charAt(1) == 116 &&
			that.charAt(2) == 101 &&
			that.charAt(3) == 112 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.STATIC)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 115 &&
			that.charAt(1) == 116 &&
			that.charAt(2) == 97 &&
			that.charAt(3) == 116 &&
			that.charAt(4) == 105 &&
			that.charAt(5) == 99 &&
			that.isBoundary(6)
		{
			return that.next(6)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.STRING)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 34 { // "
			if match ?= regex.double_quote.exec(that.substringAt(1)) {
				return that.next(match[0].length + 1)
			}
		}
		else if c == 39 { // '
			if match ?= regex.single_quote.exec(that.substringAt(1)) {
				return that.next(match[0].length + 1)
			}
		}

		return false
	} # }}}
	`\(Token.TEMPLATE_BEGIN)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 96 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.TEMPLATE_END)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 96 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.THEN)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 116 &&
			that.charAt(1) == 104 &&
			that.charAt(2) == 101 &&
			that.charAt(3) == 110 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.THROW)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 116 &&
			that.charAt(1) == 104 &&
			that.charAt(2) == 114 &&
			that.charAt(3) == 111 &&
			that.charAt(4) == 119 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.TILDE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 126 {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.TILDE_TILDE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 126 && that.charAt(1) == 126 {
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.TIMES)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 116 &&
			that.charAt(1) == 105 &&
			that.charAt(2) == 109 &&
			that.charAt(3) == 101 &&
			that.charAt(4) == 115 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.TO)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 116 &&
			that.charAt(1) == 111 &&
			that.charAt(2) != 126 &&
			that.isBoundary(2)
		{
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.TO_TILDE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 116 &&
			that.charAt(1) == 111 &&
			that.charAt(2) == 126 &&
			that.isBoundary(3)
		{
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.TRY)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 116 &&
			that.charAt(1) == 114 &&
			that.charAt(2) == 121 &&
			that.isBoundary(3)
		{
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.UNDERSCORE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if c == 95 && that.isBoundary(1) {
			return that.next(1)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.UNLESS)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 117 &&
			that.charAt(1) == 110 &&
			that.charAt(2) == 108 &&
			that.charAt(3) == 101 &&
			that.charAt(4) == 115 &&
			that.charAt(5) == 115 &&
			that.isBoundary(6)
		{
			return that.next(6)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.UNTIL)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 117 &&
			that.charAt(1) == 110 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 105 &&
			that.charAt(4) == 108 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.UP)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 117 &&
			that.charAt(1) == 112 &&
			that.isBoundary(2)
		{
			return that.next(2)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.VAR)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 118 &&
			that.charAt(1) == 97 &&
			that.charAt(2) == 114 &&
			that.isBoundary(3)
		{
			return that.next(3)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.WHEN)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 119 &&
			that.charAt(1) == 104 &&
			that.charAt(2) == 101 &&
			that.charAt(3) == 110 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.WHILE)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 119 &&
			that.charAt(1) == 104 &&
			that.charAt(2) == 105 &&
			that.charAt(3) == 108 &&
			that.charAt(4) == 101 &&
			that.isBoundary(5)
		{
			return that.next(5)
		}
		else {
			return false
		}
	} # }}}
	`\(Token.WITH)`(that: Scanner, mut c: Number): Boolean { # {{{
		if	c == 119 &&
			that.charAt(1) == 105 &&
			that.charAt(2) == 116 &&
			that.charAt(3) == 104 &&
			that.isBoundary(4)
		{
			return that.next(4)
		}
		else {
			return false
		}
	} # }}}
}

class Scanner {
	private {
		_column: Number			= 1
		_data: String
		_eof: Boolean			= false
		_index: Number			= 0
		_line: Number			= 1
		_length: Number
		_nextColumn: Number		= 1
		_nextIndex: Number		= 0
		_nextLine: Number		= 1
	}
	constructor(@data) { # {{{
		@length = @data.length
	} # }}}
	charAt(d: Number): Number => @data.charCodeAt(@index + d)
	char(): String => @eof ? 'EOF' : @data[@index]
	column(): @column
	commit(): Token? { # {{{
		if @eof {
			return null
		}
		else {
			@column = @nextColumn
			@line = @nextLine
			@index = @nextIndex

			return Token.INVALID
		}
	} # }}}
	endPosition(): Position { # {{{
		return new Position(
			line: @nextLine
			column: @nextColumn
		)
	} # }}}
	eof(): Token { # {{{
		@eof = true

		return Token.EOF
	} # }}}
	isBoundary(d: Number): Boolean { # {{{
		var c = @data.charCodeAt(@index + d)

		return c == 9 || c == 10 || c == 13 || c == 32 || !((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 36)
	} # }}}
	isEOF(): Boolean => @eof
	isSpace(d: Number): Boolean { # {{{
		var c = @data.charCodeAt(@index + d)

		return c == 9 || c == 10 || c == 13 || c == 32
	} # }}}
	line(): @line
	mark(): Marker { # {{{
		return new Marker(
			eof: @eof
			index: @index
			line: @line
			column: @column
		)
	} # }}}
	match(...tokens: Token): Token { # {{{
		if @eof {
			return Token.EOF
		}
		else {
			var c = @skip(@index)

			if c == -1 {
				return Token.EOF
			}

			for var token in tokens {
				if recognize[token](this, c) {
					return token
				}
			}

			return Token.INVALID
		}
	} # }}}
	matchM(matcher: Function, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
		if @eof {
			return Token.EOF
		}
		else {
			return matcher(this, @index, eMode, fMode, pMode)
		}
	} # }}}
	matchNS(...tokens: Token): Token { # {{{
		if @eof {
			return Token.EOF
		}
		else {
			var c = @data.charCodeAt(@index)

			for var token in tokens {
				if recognize[token](this, c) {
					return token
				}
			}

			return Token.INVALID
		}
	} # }}}
	next(length: Number): Boolean { # {{{
		@nextIndex = @index + length
		@nextColumn = @column + length

		return true
	} # }}}
	nextLine(length: Number): Boolean { # {{{
		@nextIndex = @index + length
		@nextColumn = 1
		@nextLine = @line + 1

		return true
	} # }}}
	position(): Range { # {{{
		return new Range(
			start: new Position(
				line: @line
				column: @column
			)
			end: new Position(
				line: @nextLine
				column: @nextColumn
			)
		)
	} # }}}
	readLine(): String { # {{{
		var mut index = @index

		while index < @length {
			var c = @data.charCodeAt(index)

			if c == 13 && @data.charCodeAt(index + 1) == 10 {
				var text = @data.substring(@index, index)

				@nextColumn += index - @index
				@nextIndex = @index = index

				return text
			}
			else if c == 10 | 13 {
				var text = @data.substring(@index, index)

				@nextColumn += index - @index
				@nextIndex = @index = index

				return text
			}

			index += 1
		}

		@eof()

		return ''
	} # }}}
	readIndent(): String { # {{{
		var mut index = @index

		while index < @length {
			var c = @data.charCodeAt(index)

			if c == 9 | 32 {
				index += 1
			}
			else {
				var text = @data.substring(@index, index)

				@nextColumn += index - @index
				@nextIndex = @index = index

				return text
			}
		}

		@eof()

		return ''
	} # }}}
	rollback(mark: Marker): Boolean { # {{{
		@eof = mark.eof
		@index = mark.index
		@line = mark.line
		@column = mark.column

		return true
	} # }}}
	scanIdentifier(substr: Boolean): String? { # {{{
		var dyn index = @index

		var dyn c = @data.charCodeAt(index)
		while index < @length &&
		(
			(c <- @data.charCodeAt(index)) == 36 ||
			(c >= 48 && c <= 57) ||
			(c >= 65 && c <= 90) ||
			c == 95 ||
			(c >= 97 && c <= 122)
		) {
			index += 1
		}

		if substr {
			var dyn identifier = @data.substring(@index + 1, index)

			@next(index - @index)

			return identifier
		}
		else {
			@next(index - @index)

			return null
		}
	} # }}}
	skip(): Void { # {{{
		@skip(@index)
	} # }}}
	private skip(mut index: Number): Number { # {{{
		while index < @length {
			var mut c = @data.charCodeAt(index)
			// console.log('sk', index, c, @line, @column)

			if c == 32 || c == 9 {
				// skip
				@column += 1
			}
			else if c == 35 { // #
				var oldIndex = index

				c = @data.charCodeAt(index + 1)

				if c != 32 && c != 9 {
					@nextIndex = @index = index
					@nextColumn = @column
					@nextLine = @line

					return 35
				}

				index += 2

				// skip spaces
				while index < @length {
					c = @data.charCodeAt(index)

					if c != 32 && c != 9 {
						break
					}

					index += 1
				}

				c = @data.charCodeAt(index + 1)

				if c == 123 { // {
					if @data.charCodeAt(index + 2) != 123 && @data.charCodeAt(index + 3) != 123 {
						@nextIndex = @index = oldIndex
						@nextColumn = @column
						@nextLine = @line

						return 35
					}

					index += 2
				}
				else if c == 125 { // }
					if @data.charCodeAt(index + 2) != 125 && @data.charCodeAt(index + 3) != 125 {
						@nextIndex = @index = oldIndex
						@nextColumn = @column
						@nextLine = @line

						return 35
					}

					index += 2
				}
				else {
					@nextIndex = @index = oldIndex
					@nextColumn = @column
					@nextLine = @line

					return 35
				}

				while index + 1 < @length && @data.charCodeAt(index + 1) != 10 {
					index += 1
				}

				@column += index - oldIndex
			}
			else if c == 47 { // /
				c = @data.charCodeAt(index + 1)

				if c == 42 { // /*
					var oldIndex = index

					var dyn line = @line
					var dyn column = @column

					var dyn left = 1
					var dyn lineIndex = index - @column

					index += 2

					while index < @length {
						c = @data.charCodeAt(index)

						if c == 10 {
							line += 1
							column = 1

							lineIndex = index
						}
						else if c == 42 && @data.charCodeAt(index + 1) == 47 { // * /
							left -= 1

							if left == 0 {
								index += 1
								column += index - lineIndex

								break
							}
						}
						else if c == 47 && @data.charCodeAt(index + 1) == 42 { // / *
							left += 1
						}

						index += 1
					}

					if left != 0 {
						@nextIndex = @index = oldIndex
						@nextColumn = @column
						@nextLine = @line

						return 47
					}

					@line = line
					@column = column
				}
				else if c == 47 { // //
					var lineIndex = index

					index += 1

					while index < @length && @data.charCodeAt(index + 1) != 10 {
						index += 1
					}

					@column += index - lineIndex
				}
				else {
					@nextIndex = @index = index
					@nextColumn = @column
					@nextLine = @line

					return 47
				}
			}
			else {
				@nextIndex = @index = index
				@nextColumn = @column
				@nextLine = @line

				return c
			}

			index += 1
		}

		@nextIndex = @index = index
		@nextColumn = @column
		@nextLine = @line

		@eof()

		return -1
	} # }}}
	skipComments(): Number { # {{{
		var dyn index = @index

		while index < @length {
			var mut c = @data.charCodeAt(index)
			// console.log('cm', index, c, @line, @column)

			if c == 32 || c == 9 {
				// skip
				@column += 1
			}
			else if c == 47 { // /
				c = @data.charCodeAt(index + 1)

				if c == 42 { // /*
					var oldIndex = index

					var dyn line = @line
					var dyn column = @column

					var dyn left = 1
					var dyn lineIndex = index - @column

					index += 2

					while index < @length {
						c = @data.charCodeAt(index)

						if c == 10 {
							line += 1
							column = 1

							lineIndex = index
						}
						else if c == 42 && @data.charCodeAt(index + 1) == 47 { // * /
							left -= 1

							if left == 0 {
								index += 1
								column += index - lineIndex

								break
							}
						}
						else if c == 47 && @data.charCodeAt(index + 1) == 42 { // / *
							left += 1
						}

						index += 1
					}

					if left != 0 {
						@nextIndex = @index = oldIndex
						@nextColumn = @column
						@nextLine = @line

						return 47
					}

					index += 1

					// skip spaces
					while index < @length {
						c = @data.charCodeAt(index)

						if c == 32 || c == 9 {
							// skip
							column += 1
						}
						else {
							break
						}

						index += 1
					}

					// skip new line
					c = @data.charCodeAt(index)

					if c == 13 && @data.charCodeAt(index + 1) == 10 {
						line += 1
						column = 1
						index += 1
					}
					else if c == 10 || c == 13 {
						line += 1
						column = 1
					}
					else {
						index -= 1
					}

					@line = line
					@column = column
				}
				else if c == 47 { // //
					var lineIndex = index

					index += 1

					while index < @length && @data.charCodeAt(index + 1) != 10 {
						index += 1
					}

					@column += index - lineIndex

					// skip new line
					c = @data.charCodeAt(index + 1)

					if c == 13 && @data.charCodeAt(index + 2) == 10 {
						@line += 1
						@column = 1
						index += 2
					}
					else if c == 10 || c == 13 {
						@line += 1
						@column = 1
						index += 1
					}
				}
				else {
					@nextIndex = @index = index
					@nextColumn = @column
					@nextLine = @line

					return 47
				}
			}
			else {
				@nextIndex = @index = index
				@nextColumn = @column
				@nextLine = @line

				return c
			}

			index += 1
		}

		@nextIndex = @index = index
		@nextColumn = @column
		@nextLine = @line

		@eof()

		return -1
	} # }}}
	skipNewLine(mut index: Number = @index): Number { # {{{
		while index < @length {
			var mut c = @data.charCodeAt(index)
			// console.log('nl', index, c, @line, @column)

			if c == 13 && @data.charCodeAt(index + 1) == 10 {
				@line += 1
				@column = 1
				index += 1
			}
			else if c == 10 || c == 13 {
				@line += 1
				@column = 1
			}
			else if c == 32 || c == 9 {
				// skip
				@column += 1
			}
			else if c == 35 { // #
				var oldIndex = index

				c = @data.charCodeAt(index + 1)

				if c != 32 && c != 9 {
					@nextIndex = @index = index
					@nextColumn = @column
					@nextLine = @line

					return 35
				}

				index += 2

				// skip spaces
				while index < @length {
					c = @data.charCodeAt(index)

					if c != 32 && c != 9 {
						break
					}

					index += 1
				}

				c = @data.charCodeAt(index + 1)

				if c == 123 { // {
					if @data.charCodeAt(index + 2) != 123 && @data.charCodeAt(index + 3) != 123 {
						@nextIndex = @index = oldIndex
						@nextColumn = @column
						@nextLine = @line

						return 35
					}

					index += 2
				}
				else if c == 125 { // }
					if @data.charCodeAt(index + 2) != 125 && @data.charCodeAt(index + 3) != 125 {
						@nextIndex = @index = oldIndex
						@nextColumn = @column
						@nextLine = @line

						return 35
					}

					index += 2
				}
				else {
					@nextIndex = @index = oldIndex
					@nextColumn = @column
					@nextLine = @line

					return 35
				}

				while index + 1 < @length && @data.charCodeAt(index + 1) != 10 {
					index += 1
				}

				@column += index - oldIndex
			}
			else if c == 47 { // /
				c = @data.charCodeAt(index + 1)

				if c == 42 { // /*
					var oldIndex = index

					var dyn line = @line
					var dyn column = @column

					var dyn left = 1
					var dyn lineIndex = index - @column

					index += 2

					while index < @length {
						c = @data.charCodeAt(index)

						if c == 10 {
							line += 1
							column = 1

							lineIndex = index
						}
						else if c == 42 && @data.charCodeAt(index + 1) == 47 { // * /
							left -= 1

							if left == 0 {
								index += 1

								column += index - lineIndex

								break
							}
						}
						else if c == 47 && @data.charCodeAt(index + 1) == 42 { // / *
							left += 1
						}

						index += 1
					}

					if left != 0 {
						@nextIndex = @index = oldIndex
						@nextColumn = @column
						@nextLine = @line

						return 47
					}

					@line = line
					@column = column
				}
				else if c == 47 { // //
					var lineIndex = index

					index += 1

					while index < @length && @data.charCodeAt(index + 1) != 10 {
						index += 1
					}

					@column += index - lineIndex
				}
				else {
					@nextIndex = @index = index
					@nextColumn = @column
					@nextLine = @line

					return 47
				}
			}
			else {
				@nextIndex = @index = index
				@nextColumn = @column
				@nextLine = @line

				return c
			}

			index += 1
		}

		@nextIndex = @index = index
		@nextColumn = @column
		@nextLine = @line

		@eof()

		return -1
	} # }}}
	startPosition(): Position { # {{{
		return new Position(
			line: @line
			column: @column
		)
	} # }}}
	substringAt(d: Number): String => @data.substring(@index + d)
	test(token: Token): Boolean { # {{{
		if @eof {
			return Token.EOF == token
		}
		else {
			var c = @skip(@index)

			if c == -1 {
				return Token.EOF == token
			}

			return recognize[token](this, c)
		}
	} # }}}
	testNS(token: Token): Boolean { # {{{
		if @eof {
			return Token.EOF == token
		}
		else {
			return recognize[token](this, @data.charCodeAt(@index))
		}
	} # }}}
	toDebug(): String => `line: \(@line), column: \(@column), token: \(@toQuote())`
	toQuote(): String { # {{{
		if @eof {
			return '"EOF"'
		}
		else if @index + 1 >= @nextIndex {
			var c = @data.charCodeAt(@index)

			if c == 10 {
				return '"NewLine"'
			}
			else {
				return `"\(@data[@index])"`
			}
		}
		else {
			return `"\(@data.substring(@index, @nextIndex))"`
		}
	} # }}}
	value(): String => @data.substring(@index, @nextIndex)
	value(token: Token): String | Array<String> { # {{{
		if overhauls[token] is Function {
			return overhauls[token](@data.substring(@index, @nextIndex))
		}
		else {
			return @data.substring(@index, @nextIndex)
		}
	} # }}}
}
