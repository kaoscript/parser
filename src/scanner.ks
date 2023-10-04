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
	ASTERISK_ASTERISK
	ASTERISK_DOLLAR_LEFT_ROUND
	ASTERISK_EQUALS
	ASTERISK_PIPE_RIGHT_ANGLE
	ASTERISK_PIPE_RIGHT_ANGLE_HASH
	ASTERISK_PIPE_RIGHT_ANGLE_QUESTION
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
	CHARACTER_NUMBER
	CLASS
	CLASS_VERSION
	COLON
	COLON_EXCLAMATION
	COLON_QUESTION
	COLON_RIGHT_ANGLE
	COMMA
	CONST
	CONTINUE
	DECIMAL_NUMBER
	DISCLOSE
	DO
	DOT
	DOT_DOT
	DOT_DOT_DOT
	DOWN
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
	HASH_LEFT_ANGLE_PIPE
	HASH_LEFT_ANGLE_PIPE_ASTERISK
	HASH_LEFT_ROUND
	HASH_LEFT_SQUARE
	HASH_S_LEFT_ROUND
	HASH_W_LEFT_ROUND
	HEX_NUMBER
	IDENTIFIER
	IF
	IMPL
	IMPLEMENTS
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
	LEFT_ANGLE_MINUS
	LEFT_ANGLE_PIPE
	LEFT_ANGLE_PIPE_ASTERISK
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
	PIPE
	PIPE_RIGHT_ANGLE
	PIPE_RIGHT_ANGLE_HASH
	PIPE_RIGHT_ANGLE_QUESTION
	PIPE_PIPE
	PIPE_PIPE_EQUALS
	PLUS
	PLUS_AMPERSAND
	PLUS_AMPERSAND_EQUALS
	PLUS_CARET
	PLUS_CARET_EQUALS
	PLUS_EQUALS
	PLUS_LEFT_ANGLE
	PLUS_LEFT_ANGLE_EQUALS
	PLUS_PIPE
	PLUS_PIPE_EQUALS
	PLUS_RIGHT_ANGLE
	PLUS_RIGHT_ANGLE_EQUALS
	PRIVATE
	PROTECTED
	PROXY
	PUBLIC
	QUESTION
	QUESTION_EQUALS
	QUESTION_DOT
	QUESTION_DOT_DOT
	QUESTION_LEFT_ANGLE_PIPE
	QUESTION_LEFT_ANGLE_PIPE_ASTERISK
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
	RIGHT_CURLY
	RIGHT_ROUND
	RIGHT_SQUARE
	SEALED
	SEMICOLON_SEMICOLON
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
	TYPEOF
	UNDERSCORE
	UNLESS
	UNTIL
	UP
	VALUEOF
	VAR
	WHEN
	WHILE
	WITH

	scan(scanner: Scanner, mut c: Number): Boolean {
		match this {
			.ABSTRACT { # {{{
				if	c == 97 &&
					scanner.charAt(1) == 98 &&
					scanner.charAt(2) == 115 &&
					scanner.charAt(3) == 116 &&
					scanner.charAt(4) == 114 &&
					scanner.charAt(5) == 97 &&
					scanner.charAt(6) == 99 &&
					scanner.charAt(7) == 116 &&
					scanner.isBoundary(8)
				{
					return scanner.next(8)
				}
			} # }}}
			.AMPERSAND { # {{{
				if c == 38 && scanner.charAt(1) != 61 {
					return scanner.next(1)
				}
			} # }}}
			.AMPERSAND_AMPERSAND { # {{{
				if c == 38 && scanner.charAt(1) == 38 {
					return scanner.next(2)
				}
			} # }}}
			.ASTERISK { # {{{
				if c == 0'*' && scanner.charAt(1) != 0'*' & 0'$' & 0'=' {
					return scanner.next(1)
				}
			} # }}}
			.ASTERISK_ASTERISK { # {{{
				if c == 0'*' && scanner.charAt(1) == 0'*' {
					return scanner.next(2)
				}
			} # }}}
			.AS { # {{{
				if	c == 97 &&
					scanner.charAt(1) == 115 &&
					scanner.isBoundary(2)
				{
					return scanner.next(2)
				}
			} # }}}
			.ASYNC { # {{{
				if	c == 97 &&
					scanner.charAt(1) == 115 &&
					scanner.charAt(2) == 121 &&
					scanner.charAt(3) == 110 &&
					scanner.charAt(4) == 99 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.AT { # {{{
				if c == 64 {
					return scanner.next(1)
				}
			} # }}}
			.ATTRIBUTE_IDENTIFIER { # {{{
				if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) {
					var dyn index = scanner._index

					var dyn c
					while index < scanner._length &&
					(
						(c <- scanner._data.charCodeAt(index)) == 45 ||
						c == 46 ||
						(c >= 48 && c <= 57) ||
						(c >= 65 && c <= 90) ||
						c == 95 ||
						(c >= 97 && c <= 122)
					) {
						index += 1
					}

					return scanner.next(index - scanner._index)
				}
			} # }}}
			.AUTO { # {{{
				if	c == 97 &&
					scanner.charAt(1) == 117 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 111 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.AWAIT { # {{{
				if	c == 97 &&
					scanner.charAt(1) == 119 &&
					scanner.charAt(2) == 97 &&
					scanner.charAt(3) == 105 &&
					scanner.charAt(4) == 116 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.BACKSLASH { # {{{
				if c == 92 {
					c = scanner.charAt(1)

					return scanner.next(1)
				}
			} # }}}
			.BREAK { # {{{
				if	c == 98 &&
					scanner.charAt(1) == 114 &&
					scanner.charAt(2) == 101 &&
					scanner.charAt(3) == 97 &&
					scanner.charAt(4) == 107 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.BUT { # {{{
				if	c == 98 &&
					scanner.charAt(1) == 117 &&
					scanner.charAt(2) == 116 &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.CARET { # {{{
				if c == 0'^' && scanner.charAt(1) != 0'=' {
					return scanner.next(1)
				}
			} # }}}
			.CARET_CARET { # {{{
				if c == 0'^' && scanner.charAt(1) == 0'^' {
					return scanner.next(2)
				}
			} # }}}
			.CATCH { # {{{
				if	c == 99 &&
					scanner.charAt(1) == 97 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 99 &&
					scanner.charAt(4) == 104 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.CLASS { # {{{
				if	c == 99 &&
					scanner.charAt(1) == 108 &&
					scanner.charAt(2) == 97 &&
					scanner.charAt(3) == 115 &&
					scanner.charAt(4) == 115 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.CLASS_VERSION { # {{{
				if var match ?= regex.class_version.exec(scanner.substringAt(0)) {
					return scanner.next(match[0].length)
				}
			} # }}}
			.COLON { # {{{
				if c == 0':' && scanner.charAt(1) != 0'>' {
					return scanner.next(1)
				}
			} # }}}
			.COLON_RIGHT_ANGLE { # {{{
				if c == 0':' && scanner.charAt(1) == 0'>' {
					return scanner.next(2)
				}
			} # }}}
			.COMMA { # {{{
				if c == 44 {
					return scanner.next(1)
				}
			} # }}}
			.CONST { # {{{
				if	c == 0'c' &&
					scanner.charAt(1) == 0'o' &&
					scanner.charAt(2) == 0'n' &&
					scanner.charAt(3) == 0's' &&
					scanner.charAt(4) == 0't' &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.CONTINUE { # {{{
				if	c == 99 &&
					scanner.charAt(1) == 111 &&
					scanner.charAt(2) == 110 &&
					scanner.charAt(3) == 116 &&
					scanner.charAt(4) == 105 &&
					scanner.charAt(5) == 110 &&
					scanner.charAt(6) == 117 &&
					scanner.charAt(7) == 101 &&
					scanner.isBoundary(8)
				{
					return scanner.next(8)
				}
			} # }}}
			.DOT { # {{{
				if c == 46 && scanner.charAt(1) != 46 {
					return scanner.next(1)
				}
			} # }}}
			.DOT_DOT { # {{{
				if c == 46 && scanner.charAt(1) == 46 && scanner.charAt(2) != 46 {
					return scanner.next(2)
				}
			} # }}}
			.DOT_DOT_DOT { # {{{
				if c == 46 && scanner.charAt(1) == 46 && scanner.charAt(2) == 46 {
					return scanner.next(3)
				}
			} # }}}
			.DOWN { # {{{
				if	c == 100 &&
					scanner.charAt(1) == 111 &&
					scanner.charAt(2) == 119 &&
					scanner.charAt(3) == 110 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.DYN { # {{{
				if	c == 100 &&
					scanner.charAt(1) == 121 &&
					scanner.charAt(2) == 110 &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.ELSE { # {{{
				if	c == 101 &&
					scanner.charAt(1) == 108 &&
					scanner.charAt(2) == 115 &&
					scanner.charAt(3) == 101 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.ELSE_IF { # {{{
				if	c == 101 &&
					scanner.charAt(1) == 108 &&
					scanner.charAt(2) == 115 &&
					scanner.charAt(3) == 101 &&
					scanner.charAt(4) == 32 &&
					scanner.charAt(5) == 105 &&
					scanner.charAt(6) == 102 &&
					scanner.isBoundary(7)
				{
					return scanner.next(7)
				}
			} # }}}
			.ENUM { # {{{
				if	c == 101 &&
					scanner.charAt(1) == 110 &&
					scanner.charAt(2) == 117 &&
					scanner.charAt(3) == 109 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.EQUALS { # {{{
				if c == 61 && scanner.charAt(1) != 61 & 62 {
					return scanner.next(1)
				}
			} # }}}
			.EQUALS_RIGHT_ANGLE { # {{{
				if c == 61 && scanner.charAt(1) == 62{
					return scanner.next(2)
				}
			} # }}}
			.EXCLAMATION { # {{{
				if c == 33 {
					return scanner.next(1)
				}
			} # }}}
			.EXCLAMATION_QUESTION { # {{{
				if c == 33 && scanner.charAt(1) == 63 {
					return scanner.next(2)
				}
			} # }}}
			.EXTENDS { # {{{
				if	c == 101 &&
					scanner.charAt(1) == 120 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 101 &&
					scanner.charAt(4) == 110 &&
					scanner.charAt(5) == 100 &&
					scanner.charAt(6) == 115 &&
					scanner.isBoundary(7)
				{
					return scanner.next(7)
				}
			} # }}}
			.FINAL { # {{{
				if	c == 102 &&
					scanner.charAt(1) == 105 &&
					scanner.charAt(2) == 110 &&
					scanner.charAt(3) == 97 &&
					scanner.charAt(4) == 108 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.FINALLY { # {{{
				if	c == 102 &&
					scanner.charAt(1) == 105 &&
					scanner.charAt(2) == 110 &&
					scanner.charAt(3) == 97 &&
					scanner.charAt(4) == 108 &&
					scanner.charAt(5) == 108 &&
					scanner.charAt(6) == 121 &&
					scanner.isBoundary(7)
				{
					return scanner.next(7)
				}
			} # }}}
			.FOR { # {{{
				if	c == 102 &&
					scanner.charAt(1) == 111 &&
					scanner.charAt(2) == 114 &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.FROM { # {{{
				if	c == 102 &&
					scanner.charAt(1) == 114 &&
					scanner.charAt(2) == 111 &&
					scanner.charAt(3) == 109 &&
					scanner.charAt(4) != 126 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.FROM_TILDE { # {{{
				if	c == 102 &&
					scanner.charAt(1) == 114 &&
					scanner.charAt(2) == 111 &&
					scanner.charAt(3) == 109 &&
					scanner.charAt(4) == 126 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.FUNC { # {{{
				if	c == 102 &&
					scanner.charAt(1) == 117 &&
					scanner.charAt(2) == 110 &&
					scanner.charAt(3) == 99 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.GET { # {{{
				if	c == 103 &&
					scanner.charAt(1) == 101 &&
					scanner.charAt(2) == 116 &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.HASH { # {{{
				if c == 35 && scanner.charAt(1) != 33 & 35 & 61 & 91 {
					return scanner.next(1)
				}
			} # }}}
			.HASH_EQUALS { # {{{
				if c == 35 && scanner.charAt(1) == 61 {
					return scanner.next(2)
				}
			} # }}}
			.HASH_EXCLAMATION { # {{{
				if c == 35 && scanner.charAt(1) == 33 && scanner.charAt(2) != 91 {
					return scanner.next(2)
				}
			} # }}}
			.HASH_EXCLAMATION_LEFT_SQUARE { # {{{
				if c == 35 && scanner.charAt(1) == 33 && scanner.charAt(2) == 91 {
					return scanner.next(3)
				}
			} # }}}
			.HASH_HASH_EQUALS { # {{{
				if c == 35 && scanner.charAt(1) == 35 && scanner.charAt(2) == 61 {
					return scanner.next(3)
				}
			} # }}}
			.HASH_LEFT_SQUARE { # {{{
				if c == 35 && scanner.charAt(1) == 91 {
					return scanner.next(2)
				}
			} # }}}
			.IDENTIFIER { # {{{
				if c == 36 || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) {
					scanner.scanIdentifier(false)

					return true
				}
				else if c == 95 && !scanner.isBoundary(1) {
					scanner.scanIdentifier(false)

					return true
				}
			} # }}}
			.IF { # {{{
				if	c == 105 &&
					scanner.charAt(1) == 102 &&
					scanner.isBoundary(2)
				{
					return scanner.next(2)
				}
			} # }}}
			.IMPLEMENTS { # {{{
				if	c == 105 &&
					scanner.charAt(1) == 109 &&
					scanner.charAt(2) == 112 &&
					scanner.charAt(3) == 108 &&
					scanner.charAt(4) == 101 &&
					scanner.charAt(5) == 109 &&
					scanner.charAt(6) == 101 &&
					scanner.charAt(7) == 110 &&
					scanner.charAt(8) == 116 &&
					scanner.charAt(9) == 115 &&
					scanner.isBoundary(10)
				{
					return scanner.next(10)
				}
			} # }}}
			.IN { # {{{
				if	c == 105 &&
					scanner.charAt(1) == 110 &&
					scanner.isBoundary(2)
				{
					return scanner.next(2)
				}
			} # }}}
			.INTERNAL { # {{{
				if	c == 105 &&
					scanner.charAt(1) == 110 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 101 &&
					scanner.charAt(4) == 114 &&
					scanner.charAt(5) == 110 &&
					scanner.charAt(6) == 97 &&
					scanner.charAt(7) == 108 &&
					scanner.isBoundary(8)
				{
					return scanner.next(8)
				}
			} # }}}
			.IS { # {{{
				if	c == 105 &&
					scanner.charAt(1) == 115 &&
					scanner.isBoundary(2)
				{
					return scanner.next(2)
				}
			} # }}}
			.LATE { # {{{
				if	c == 108 &&
					scanner.charAt(1) == 97 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 101 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.LATEINIT { # {{{
				if	c == 108 &&
					scanner.charAt(1) == 97 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 101 &&
					scanner.charAt(4) == 105 &&
					scanner.charAt(5) == 110 &&
					scanner.charAt(6) == 105 &&
					scanner.charAt(7) == 116 &&
					scanner.isBoundary(8)
				{
					return scanner.next(8)
				}
			} # }}}
			.LEFT_ANGLE { # {{{
				if c == 60 {
					c = scanner.charAt(1)

					return c == 60 || c == 61 ? false : scanner.next(1)
				}
			} # }}}
			.LEFT_CURLY { # {{{
				if c == 123 {
					return scanner.next(1)
				}
			} # }}}
			.LEFT_ROUND { # {{{
				if c == 40 {
					return scanner.next(1)
				}
			} # }}}
			.LEFT_SQUARE { # {{{
				if c == 91 {
					return scanner.next(1)
				}
			} # }}}
			.MACRO { # {{{
				if	c == 109 &&
					scanner.charAt(1) == 97 &&
					scanner.charAt(2) == 99 &&
					scanner.charAt(3) == 114 &&
					scanner.charAt(4) == 111 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.MATCH { # {{{
				if	c == 109 &&
					scanner.charAt(1) == 97 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 99 &&
					scanner.charAt(4) == 104 &&
					scanner.isSpace(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.MINUS { # {{{
				if c == 45 && scanner.charAt(1) != 61 {
					return scanner.next(1)
				}
			} # }}}
			.ML_BACKQUOTE { # {{{
				if c == 96 && scanner.charAt(1) == 96 && scanner.charAt(2) == 96 {
					return scanner.next(3)
				}
			} # }}}
			.ML_DOUBLE_QUOTE { # {{{
				if c == 34 && scanner.charAt(1) == 34 && scanner.charAt(2) == 34 {
					return scanner.next(3)
				}
			} # }}}
			.ML_SINGLE_QUOTE { # {{{
				if c == 39 && scanner.charAt(1) == 39 && scanner.charAt(2) == 39 {
					return scanner.next(3)
				}
			} # }}}
			.ML_TILDE { # {{{
				if c == 126 && scanner.charAt(1) == 126 && scanner.charAt(2) == 126 {
					return scanner.next(3)
				}
			} # }}}
			.MUT { # {{{
				if	c == 0'm' &&
					scanner.charAt(1) == 0'u' &&
					scanner.charAt(2) == 0't' &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.NEW { # {{{
				if	c == 0'n' &&
					scanner.charAt(1) == 0'e' &&
					scanner.charAt(2) == 0'w' &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.NEWLINE { # {{{
				if c == 13 && scanner.charAt(1) == 10 {
					return scanner.nextLine(2)
				}
				else if c == 10 || c == 13 {
					return scanner.nextLine(1)
				}

				return false
			} # }}}
			.NUMERAL { # {{{
				if 48 <= c <= 57 {
					var mut i = 1

					while 48 <= scanner.charAt(i) <= 57 {
						i += 1
					}

					if scanner.isBoundary(i) {
						return scanner.next(i)
					}
				}

				return false
			} # }}}
			.OF { # {{{
				if	c == 111 &&
					scanner.charAt(1) == 102 &&
					scanner.isBoundary(2)
				{
					return scanner.next(2)
				}
			} # }}}
			.ON { # {{{
				if	c == 111 &&
					scanner.charAt(1) == 110 &&
					scanner.isBoundary(2)
				{
					return scanner.next(2)
				}
			} # }}}
			.OVERRIDE { # {{{
				if	c == 111 &&
					scanner.charAt(1) == 118 &&
					scanner.charAt(2) == 101 &&
					scanner.charAt(3) == 114 &&
					scanner.charAt(4) == 114 &&
					scanner.charAt(5) == 105 &&
					scanner.charAt(6) == 100 &&
					scanner.charAt(7) == 101 &&
					scanner.isBoundary(8)
				{
					return scanner.next(8)
				}
			} # }}}
			.OVERWRITE { # {{{
				if	c == 111 &&
					scanner.charAt(1) == 118 &&
					scanner.charAt(2) == 101 &&
					scanner.charAt(3) == 114 &&
					scanner.charAt(4) == 119 &&
					scanner.charAt(5) == 114 &&
					scanner.charAt(6) == 105 &&
					scanner.charAt(7) == 116 &&
					scanner.charAt(8) == 101 &&
					scanner.isBoundary(9)
				{
					return scanner.next(9)
				}
			} # }}}
			.PASS { # {{{
				if	c == 112 &&
					scanner.charAt(1) == 97 &&
					scanner.charAt(2) == 115 &&
					scanner.charAt(3) == 115 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.PERCENT { # {{{
				if c == 37 {
					return scanner.next(1)
				}
			} # }}}
			.PIPE { # {{{
				if c == 124 && scanner.charAt(1) != 61 {
					return scanner.next(1)
				}
			} # }}}
			.PIPE_PIPE { # {{{
				if c == 124 && scanner.charAt(1) == 124 {
					return scanner.next(2)
				}
			} # }}}
			.PRIVATE { # {{{
				if	c == 112 &&
					scanner.charAt(1) == 114 &&
					scanner.charAt(2) == 105 &&
					scanner.charAt(3) == 118 &&
					scanner.charAt(4) == 97 &&
					scanner.charAt(5) == 116 &&
					scanner.charAt(6) == 101 &&
					scanner.isBoundary(7)
				{
					return scanner.next(7)
				}
			} # }}}
			.PROTECTED { # {{{
				if	c == 112 &&
					scanner.charAt(1) == 114 &&
					scanner.charAt(2) == 111 &&
					scanner.charAt(3) == 116 &&
					scanner.charAt(4) == 101 &&
					scanner.charAt(5) == 99 &&
					scanner.charAt(6) == 116 &&
					scanner.charAt(7) == 101 &&
					scanner.charAt(8) == 100 &&
					scanner.isBoundary(9)
				{
					return scanner.next(9)
				}
			} # }}}
			.PROXY { # {{{
				if	c == 112 &&
					scanner.charAt(1) == 114 &&
					scanner.charAt(2) == 111 &&
					scanner.charAt(3) == 120 &&
					scanner.charAt(4) == 121 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.PUBLIC { # {{{
				if	c == 112 &&
					scanner.charAt(1) == 117 &&
					scanner.charAt(2) == 98 &&
					scanner.charAt(3) == 108 &&
					scanner.charAt(4) == 105 &&
					scanner.charAt(5) == 99 &&
					scanner.isBoundary(6)
				{
					return scanner.next(6)
				}
			} # }}}
			.QUESTION { # {{{
				if c == 63 && scanner.charAt(1) != 61 & 63 {
					return scanner.next(1)
				}
			} # }}}
			.QUESTION_DOT { # {{{
				if c == 0'?' && scanner.charAt(1) == 0'.' && scanner.charAt(2) != 0'.' {
					return scanner.next(2)
				}
			} # }}}
			.QUESTION_EQUALS { # {{{
				if c == 63 && scanner.charAt(1) == 61 {
					return scanner.next(2)
				}
			} # }}}
			.QUESTION_OPERATOR { # {{{
				if c == 0'?' {
					return scanner.charAt(1) == 40 | 46 | 61 | 63 | 91 ? false : scanner.next(1)
				}
			} # }}}
			.QUESTION_QUESTION { # {{{
				if c == 63 && scanner.charAt(1) == 63 && scanner.charAt(2) != 61 {
					return scanner.next(2)
				}
			} # }}}
			.QUESTION_QUESTION_EQUALS { # {{{
				if c == 63 && scanner.charAt(1) == 63 && scanner.charAt(2) == 61 {
					return scanner.next(3)
				}
			} # }}}
			.REPEAT { # {{{
				if	c == 114 &&
					scanner.charAt(1) == 101 &&
					scanner.charAt(2) == 112 &&
					scanner.charAt(3) == 101 &&
					scanner.charAt(4) == 97 &&
					scanner.charAt(5) == 116 &&
					scanner.isBoundary(6)
				{
					return scanner.next(6)
				}
			} # }}}
			.RETURN { # {{{
				if	c == 114 &&
					scanner.charAt(1) == 101 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 117 &&
					scanner.charAt(4) == 114 &&
					scanner.charAt(5) == 110 &&
					scanner.isBoundary(6)
				{
					return scanner.next(6)
				}
			} # }}}
			.RIGHT_ANGLE { # {{{
				if c == 62 {
					return scanner.next(1)
				}
			} # }}}
			.RIGHT_CURLY { # {{{
				if c == 125 {
					return scanner.next(1)
				}
			} # }}}
			.RIGHT_ROUND { # {{{
				if c == 41 {
					return scanner.next(1)
				}
			} # }}}
			.RIGHT_SQUARE { # {{{
				if c == 93 {
					return scanner.next(1)
				}
			} # }}}
			.SEMICOLON_SEMICOLON { # {{{
				if c == 0';' && scanner.charAt(1) == 0';' {
					return scanner.next(2)
				}
			} # }}}
			.SET { # {{{
				if	c == 115 &&
					scanner.charAt(1) == 101 &&
					scanner.charAt(2) == 116 &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.SPLIT { # {{{
				if	c == 115 &&
					scanner.charAt(1) == 112 &&
					scanner.charAt(2) == 108 &&
					scanner.charAt(3) == 105 &&
					scanner.charAt(4) == 116 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.STEP { # {{{
				if	c == 115 &&
					scanner.charAt(1) == 116 &&
					scanner.charAt(2) == 101 &&
					scanner.charAt(3) == 112 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.STATIC { # {{{
				if	c == 115 &&
					scanner.charAt(1) == 116 &&
					scanner.charAt(2) == 97 &&
					scanner.charAt(3) == 116 &&
					scanner.charAt(4) == 105 &&
					scanner.charAt(5) == 99 &&
					scanner.isBoundary(6)
				{
					return scanner.next(6)
				}
			} # }}}
			.STRING { # {{{
				if c == 0'"' {
					if var match ?= regex.double_quote.exec(scanner.substringAt(1)) {
						return scanner.next(match[0].length + 1)
					}
				}
				else if c == 0'\'' {
					if var match ?= regex.single_quote.exec(scanner.substringAt(1)) {
						return scanner.next(match[0].length + 1)
					}
				}

				return false
			} # }}}
			.TEMPLATE_BEGIN { # {{{
				if c == 96 {
					return scanner.next(1)
				}
			} # }}}
			.TEMPLATE_END { # {{{
				if c == 96 {
					return scanner.next(1)
				}
			} # }}}
			.THEN { # {{{
				if	c == 0't' &&
					scanner.charAt(1) == 0'h' &&
					scanner.charAt(2) == 0'e' &&
					scanner.charAt(3) == 0'n' &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.THROW { # {{{
				if	c == 116 &&
					scanner.charAt(1) == 104 &&
					scanner.charAt(2) == 114 &&
					scanner.charAt(3) == 111 &&
					scanner.charAt(4) == 119 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.TILDE { # {{{
				if c == 126 && scanner.charAt(1) != 61 & 126 {
					return scanner.next(1)
				}
			} # }}}
			.TILDE_TILDE { # {{{
				if c == 126 && scanner.charAt(1) == 126 {
					return scanner.next(2)
				}
			} # }}}
			.TIMES { # {{{
				if	c == 116 &&
					scanner.charAt(1) == 105 &&
					scanner.charAt(2) == 109 &&
					scanner.charAt(3) == 101 &&
					scanner.charAt(4) == 115 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.TO { # {{{
				if	c == 116 &&
					scanner.charAt(1) == 111 &&
					scanner.charAt(2) != 126 &&
					scanner.isBoundary(2)
				{
					return scanner.next(2)
				}
			} # }}}
			.TO_TILDE { # {{{
				if	c == 116 &&
					scanner.charAt(1) == 111 &&
					scanner.charAt(2) == 126 &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.TRY { # {{{
				if	c == 116 &&
					scanner.charAt(1) == 114 &&
					scanner.charAt(2) == 121 &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.TYPEOF { # {{{
				if	c == 0't' &&
					scanner.charAt(1) == 0'y' &&
					scanner.charAt(2) == 0'p' &&
					scanner.charAt(3) == 0'e' &&
					scanner.charAt(4) == 0'o' &&
					scanner.charAt(5) == 0'f' &&
					scanner.isBoundary(6)
				{
					return scanner.next(6)
				}
			} # }}}
			.UNDERSCORE { # {{{
				if c == 95 && scanner.isBoundary(1) {
					return scanner.next(1)
				}
			} # }}}
			.UNLESS { # {{{
				if	c == 117 &&
					scanner.charAt(1) == 110 &&
					scanner.charAt(2) == 108 &&
					scanner.charAt(3) == 101 &&
					scanner.charAt(4) == 115 &&
					scanner.charAt(5) == 115 &&
					scanner.isBoundary(6)
				{
					return scanner.next(6)
				}
			} # }}}
			.UNTIL { # {{{
				if	c == 117 &&
					scanner.charAt(1) == 110 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 105 &&
					scanner.charAt(4) == 108 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.UP { # {{{
				if	c == 117 &&
					scanner.charAt(1) == 112 &&
					scanner.isBoundary(2)
				{
					return scanner.next(2)
				}
			} # }}}
			.VALUEOF { # {{{
				if	c == 0'v' &&
					scanner.charAt(1) == 0'a' &&
					scanner.charAt(2) == 0'l' &&
					scanner.charAt(3) == 0'u' &&
					scanner.charAt(4) == 0'e' &&
					scanner.charAt(5) == 0'o' &&
					scanner.charAt(6) == 0'f' &&
					scanner.isBoundary(7)
				{
					return scanner.next(7)
				}
			} # }}}
			.VAR { # {{{
				if	c == 118 &&
					scanner.charAt(1) == 97 &&
					scanner.charAt(2) == 114 &&
					scanner.isBoundary(3)
				{
					return scanner.next(3)
				}
			} # }}}
			.WHEN { # {{{
				if	c == 119 &&
					scanner.charAt(1) == 104 &&
					scanner.charAt(2) == 101 &&
					scanner.charAt(3) == 110 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
			.WHILE { # {{{
				if	c == 119 &&
					scanner.charAt(1) == 104 &&
					scanner.charAt(2) == 105 &&
					scanner.charAt(3) == 108 &&
					scanner.charAt(4) == 101 &&
					scanner.isBoundary(5)
				{
					return scanner.next(5)
				}
			} # }}}
			.WITH { # {{{
				if	c == 119 &&
					scanner.charAt(1) == 105 &&
					scanner.charAt(2) == 116 &&
					scanner.charAt(3) == 104 &&
					scanner.isBoundary(4)
				{
					return scanner.next(4)
				}
			} # }}}
		}

		return false
	}

	toString(): String { # {{{
		match this {
			RIGHT_CURLY => return '}'
			RIGHT_ROUND => return ')'
			RIGHT_SQUARE => return ']'
			else => return ''
		}
	} # }}}
}

var regex: Object<RegExp> = {
	binary_number: /^0b[_0-1]+[a-zA-Z]*/
	character_number: /^0'(?:[^\r\n\\]|\\[0'"\\nrvtbf])'/
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
	func ASSIGNEMENT_OPERATOR(that: Scanner, index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
		var dyn c = that.skip(index)

		if c == -1 {
			return Token.EOF
		}
		else if c == 0'!' {
			if that.charAt(2) == 61 {
				c = that.charAt(1)

				if c == 61 {
					that.next(3)

					return Token.EXCLAMATION_HASH_EQUALS
				}
				else if c == 63 {
					that.next(3)

					return Token.EXCLAMATION_QUESTION_EQUALS
				}
			}
		}
		else if c == 0'#' {
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
		else if c == 0'%' {
			if that.charAt(1) == 61 {
				that.next(2)

				return Token.PERCENT_EQUALS
			}
		}
		else if c == 0'&' {
			if that.charAt(1) == 38 && that.charAt(2) == 61 {
				that.next(3)

				return Token.AMPERSAND_AMPERSAND_EQUALS
			}
		}
		else if c == 0'*' {
			if that.charAt(1) == 61 {
				that.next(2)

				return Token.ASTERISK_EQUALS
			}
		}
		else if c == 0'+' {
			c = that.charAt(1)

			if c == 0'=' {
				that.next(2)

				return Token.PLUS_EQUALS
			}
			else if c == 0'&' && that.charAt(2) == 0'=' {
				that.next(3)

				return Token.PLUS_AMPERSAND_EQUALS
			}
			else if c == 0'|' && that.charAt(2) == 0'=' {
				that.next(3)

				return Token.PLUS_PIPE_EQUALS
			}
			else if c == 0'^' && that.charAt(2) == 0'=' {
				that.next(3)

				return Token.PLUS_CARET_EQUALS
			}
			else if c == 0'<' && that.charAt(2) == 0'=' {
				that.next(3)

				return Token.PLUS_LEFT_ANGLE_EQUALS
			}
			else if c == 0'>' && that.charAt(2) == 0'=' {
				that.next(3)

				return Token.PLUS_RIGHT_ANGLE_EQUALS
			}
		}
		else if c == 0'-' {
			if that.charAt(1) == 61 {
				that.next(2)

				return Token.MINUS_EQUALS
			}
		}
		else if c == 0'/' {
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
		else if c == 0'<' {
			c = that.charAt(1)

			if c == 0'-' {
				that.next(2)

				return Token.LEFT_ANGLE_MINUS
			}
		}
		else if c == 0'=' {
			if that.charAt(1) != 61 & 62 {
				that.next(1)

				return Token.EQUALS
			}
		}
		else if c == 0'?' {
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
		else if c == 0'^' {
			if that.charAt(1) == 94 && that.charAt(2) == 61 {
				that.next(3)

				return Token.CARET_CARET_EQUALS
			}
		}
		else if c == 0'|' {
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
		else if c == 0'!' {
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
		else if c == 0'#' {
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
			else if c == 60 && that.charAt(2) == 124 {
				if fMode !~ FunctionMode.NoPipeline {
					if that.charAt(3) == 42 {
						that.next(4)

						return Token.HASH_LEFT_ANGLE_PIPE_ASTERISK
					}
					else {
						that.next(3)

						return Token.HASH_LEFT_ANGLE_PIPE
					}
				}
			}
			else if c == 61 {
				that.next(2)

				return Token.HASH_EQUALS
			}
		}
		else if c == 0'%' {
			if that.charAt(1) == 61 {
				that.next(2)

				return Token.PERCENT_EQUALS
			}
			else {
				that.next(1)

				return Token.PERCENT
			}
		}
		else if c == 0'&' {
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
		else if c == 0'*' {
			c = that.charAt(1)

			if c == 61 {
				that.next(2)

				return Token.ASTERISK_EQUALS
			}
			else if c == 124 && that.charAt(2) == 62 {
				if fMode !~ FunctionMode.NoPipeline {
					c = that.charAt(3)

					if c == 35 {
						that.next(4)

						return Token.ASTERISK_PIPE_RIGHT_ANGLE_HASH
					}
					else if c == 63 {
						that.next(4)

						return Token.ASTERISK_PIPE_RIGHT_ANGLE_QUESTION
					}
					else {
						that.next(3)

						return Token.ASTERISK_PIPE_RIGHT_ANGLE
					}
				}
			}
			else {
				that.next(1)

				return Token.ASTERISK
			}
		}
		else if c == 0'+' {
			c = that.charAt(1)

			if c == 0'=' {
				that.next(2)

				return Token.PLUS_EQUALS
			}
			else if c == 0'&' {
				if that.charAt(2) == 0'=' {
					that.next(3)

					return Token.PLUS_AMPERSAND_EQUALS
				}
				else {
					that.next(2)

					return Token.PLUS_AMPERSAND
				}
			}
			else if c == 0'|' {
				if that.charAt(2) == 0'=' {
					that.next(3)

					return Token.PLUS_PIPE_EQUALS
				}
				else {
					that.next(2)

					return Token.PLUS_PIPE
				}
			}
			else if c == 0'^' {
				if that.charAt(2) == 0'=' {
					that.next(3)

					return Token.PLUS_CARET_EQUALS
				}
				else {
					that.next(2)

					return Token.PLUS_CARET
				}
			}
			else if c == 0'<' {
				if that.charAt(2) == 0'=' {
					that.next(3)

					return Token.PLUS_LEFT_ANGLE_EQUALS
				}
				else {
					that.next(2)

					return Token.PLUS_LEFT_ANGLE
				}
			}
			else if c == 0'>' {
				if that.charAt(2) == 0'=' {
					that.next(3)

					return Token.PLUS_RIGHT_ANGLE_EQUALS
				}
				else {
					that.next(2)

					return Token.PLUS_RIGHT_ANGLE
				}
			}
			else {
				that.next(1)

				return Token.PLUS
			}
		}
		else if c == 0'-' {
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
		else if c == 0'/' {
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
		else if c == 0'<' {
			c = that.charAt(1)

			if c == 45 {
				that.next(2)

				return Token.LEFT_ANGLE_MINUS
			}
			else if c == 61 {
				that.next(2)

				return Token.LEFT_ANGLE_EQUALS
			}
			else if c == 124 {
				if fMode !~ FunctionMode.NoPipeline {
					if that.charAt(2) == 42 {
						that.next(3)

						return Token.LEFT_ANGLE_PIPE_ASTERISK
					}
					else {
						that.next(2)

						return Token.LEFT_ANGLE_PIPE
					}
				}
			}
			else {
				that.next(1)

				return Token.LEFT_ANGLE
			}
		}
		else if c == 0'=' {
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
		else if c == 0'>' {
			c = that.charAt(1)

			if c == 61 {
				that.next(2)

				return Token.RIGHT_ANGLE_EQUALS
			}
			else {
				that.next(1)

				return Token.RIGHT_ANGLE
			}
		}
		else if c == 0'?' {
			c = that.charAt(1)

			if c == 60 && that.charAt(2) == 124 {
				if fMode !~ FunctionMode.NoPipeline {
					if that.charAt(3) == 42 {
						that.next(4)

						return Token.QUESTION_LEFT_ANGLE_PIPE_ASTERISK
					}
					else {
						that.next(3)

						return Token.QUESTION_LEFT_ANGLE_PIPE
					}
				}
			}
			else if c == 61 {
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
		else if c == 0'^' {
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
		else if c == 0'|' {
			c = that.charAt(1)

			if c == 62 {
				if fMode !~ FunctionMode.NoPipeline {
					c = that.charAt(2)

					if c == 35 {
						that.next(3)

						return Token.PIPE_RIGHT_ANGLE_HASH
					}
					else if c == 63 {
						that.next(3)

						return Token.PIPE_RIGHT_ANGLE_QUESTION
					}
					else {
						that.next(2)

						return Token.PIPE_RIGHT_ANGLE
					}
				}
			}
			else if c == 124 {
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
		else if c == 0'~' {
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
		else if c == 0'_' && !that.isBoundary(1) {
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
		else if c == 0'_' && !that.isBoundary(1) {
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
		else if c == 0'&' {
			if that.charAt(1) != 38 {
				that.next(1)

				return Token.AMPERSAND
			}
		}
		else if c == 0'^' {
			if that.charAt(1) != 94 {
				that.next(1)

				return Token.CARET
			}
		}
		else if c == 0'|' {
			if that.charAt(1) != 62 & 124 {
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
				that.isSpace(8)
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
				that.isSpace(6)
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
						that.isSpace(13)
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
							that.isSpace(14)
					{
						that.next(14)

						return Token.EXTERN_REQUIRE
					}
				}
				else if that.isSpace(6)
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
					that.isSpace(13)
				{
					that.next(13)

					return Token.INCLUDE_AGAIN
				}
				else if that.isSpace(7) {
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
						that.isSpace(14)
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
						that.isSpace(14)
					{
						that.next(14)

						return Token.REQUIRE_IMPORT
					}
				}
				else if that.isSpace(7)
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

			if var match ?= regex.dot_number.exec(substr) {
				that.next(match[0].length)

				return Token.DECIMAL_NUMBER
			}
		}
		else if c == 0'0' {
			var dyn substr = that._data.substr(that._index)

			if var match ?= regex.binary_number.exec(substr) {
				that.next(match[0].length)

				return Token.BINARY_NUMBER
			}
			else if var match ?= regex.octal_number.exec(substr) {
				that.next(match[0].length)

				return Token.OCTAL_NUMBER
			}
			else if var match ?= regex.hex_number.exec(substr) {
				that.next(match[0].length)

				return Token.HEX_NUMBER
			}
			else if var match ?= regex.character_number.exec(substr) {
				that.next(match[0].length)

				return Token.CHARACTER_NUMBER
			}
			else if var match ?= regex.decimal_number.exec(substr) {
				that.next(match[0].length)

				return Token.DECIMAL_NUMBER
			}
		}
		else if c >= 0'1' && c <= 0'9' {
			var dyn substr = that._data.substr(that._index)

			if var match ?= regex.radix_number.exec(substr) {
				that.next(match[0].length)

				return Token.RADIX_NUMBER
			}
			else if var match ?= regex.decimal_number.exec(substr) {
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
		else if c == 0'"' {
			if that.charAt(1) == 34 && that.charAt(2) == 34 {
				that.next(3)

				return Token.ML_DOUBLE_QUOTE
			}
			else if var match ?= regex.double_quote.exec(that.substringAt(1)) {
				that.next(match[0].length + 1)

				return Token.STRING
			}
		}
		else if c == 0'$' {
			that.scanIdentifier(false)

			return Token.IDENTIFIER
		}
		else if c == 0'\'' {
			if that.charAt(1) == 39 && that.charAt(2) == 39 {
				that.next(3)

				return Token.ML_SINGLE_QUOTE
			}
			else if var match ?= regex.single_quote.exec(that.substringAt(1)) {
				that.next(match[0].length + 1)

				return Token.STRING
			}
		}
		else if c == 0'(' {
			that.next(1)

			return Token.LEFT_ROUND
		}
		else if c == 0'/' {
			if var match ?= regex.regex.exec(that.substringAt(1)) {
				that.next(match[0].length + 1)

				return Token.REGEXP
			}
		}
		else if c == 0'@' {
			if eMode ~~ .AtThis || fMode ~~ .Method {
				that.next(1)

				return Token.AT
			}
		}
		else if c >= 0'A' && c <= 0'Z' {
			that.scanIdentifier(false)

			return Token.IDENTIFIER
		}
		else if c == 0'[' {
			that.next(1)

			return Token.LEFT_SQUARE
		}
		else if c == 0'_' && !that.isBoundary(1) {
			that.scanIdentifier(false)

			return Token.IDENTIFIER
		}
		else if c == 0'`' {
			if that.charAt(1) == 96 && that.charAt(2) == 96 {
				that.next(3)

				return Token.ML_BACKQUOTE
			}
			else {
				that.next(1)

				return Token.TEMPLATE_BEGIN
			}
		}
		else if c >= 0'a' && c <= 0'z' {
			that.scanIdentifier(false)

			return Token.IDENTIFIER
		}
		else if c == 0'{' {
			that.next(1)

			return Token.LEFT_CURLY
		}
		else if c == 0'~' {
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
		else if c == 0'(' {
			that.next(1)

			return Token.LEFT_ROUND
		}
		else if c == 0'*' {
			c = that.charAt(1)

			if c == 36 {
				if that.charAt(2) == 40 {
					that.next(3)

					return Token.ASTERISK_DOLLAR_LEFT_ROUND
				}
			}
		}
		else if c == 0'.' {
			if that.charAt(1) != 46 & 9 & 32 {
				that.next(1)

				return Token.DOT
			}
			else if that.charAt(1) == 46 && that.charAt(2) != 46 & 9 & 32 {
				that.next(2)

				return Token.DOT_DOT
			}
		}
		else if c == 0':' {
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
		else if c == 0'?' {
			c = that.charAt(1)

			if c == 0'(' {
				that.next(2)

				return Token.QUESTION_LEFT_ROUND
			}
			else if c == 0'.' && !(that.charAt(2) == 0'\t' | 0' ') {
				that.next(2)

				return Token.QUESTION_DOT
			}
			else if c == 0'[' {
				that.next(2)

				return Token.QUESTION_LEFT_SQUARE
			}
			else {
				var mark = that.mark()

				that
					..skipNewLine(that.index() + 1)
					..commit()

				if that.charAt(0) == 0'.' && that.charAt(1) == 0'.' {
					that.next(2)

					return Token.QUESTION_DOT_DOT
				}

				that.rollback(mark)
			}
		}
		else if c == 0'[' {
			that.next(1)

			return Token.LEFT_SQUARE
		}
		else if c == 0'^' {
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
		else if c == 0'`' {
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
		else if c == 0'!' {
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
		else if c == 0'!' {
			if !((c <- that.charAt(1)) == 0'=' || (c == 0'?' && that.charAt(2) == 0'=') || c == 9 | 32) {
				that.next(1)

				return Token.EXCLAMATION
			}
		}
		else if c == 0'#' {
			c = that.charAt(1)

			if c != 0'#' & 0'=' {
				that.next(1)

				return Token.HASH
			}
		}
		else if c == 0'*' {
			if that.charAt(1) == 0'*' {
				that.next(2)

				return Token.ASTERISK_ASTERISK
			}
		}
		else if c == 0'+' {
			if that.charAt(1) == 0'^' {
				that.next(2)

				return Token.PLUS_CARET
			}
		}
		else if c == 0'-' {
			if that.charAt(1) != 0'=' {
				that.next(1)

				return Token.MINUS
			}
		}
		else if c == 0'.' {
			if that.charAt(1) == 0'.' && that.charAt(2) == 0'.' && that.charAt(3) != 9 & 32 {
				that.next(3)

				return Token.DOT_DOT_DOT
			}
			else if eMode ~~ ExpressionMode.ImplicitMember {
				that.next(1)

				return Token.DOT
			}
		}
		else if c == 0'?' {
			if that.charAt(1) != 9 & 32 & 0'=' {
				that.next(1)

				return Token.QUESTION
			}
		}
		else if c == 0'_' {
			if that.isBoundary(1) {
				that.next(1)

				return Token.UNDERSCORE
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
				that.isSpace(8)
			{
				that.next(8)

				return Token.ABSTRACT
			}
			else if that.charAt(1) == 115 &&
					that.charAt(2) == 121 &&
					that.charAt(3) == 110 &&
					that.charAt(4) == 99 &&
					that.isSpace(5)
			{
				that.next(5)

				return Token.ASYNC
			}
			else if that.charAt(1) == 117 &&
					that.charAt(2) == 116 &&
					that.charAt(3) == 111 &&
					that.isSpace(4)
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
				that.isSpace(7)
			{
				that.next(7)

				return Token.BITMASK
			}
			else if	that.charAt(1) == 108 &&
					that.charAt(2) == 111 &&
					that.charAt(3) == 99 &&
					that.charAt(4) == 107 &&
					that.isSpace(5)
			{
				that.next(5)

				return Token.BLOCK
			}
			else if	that.charAt(1) == 114 &&
					that.charAt(2) == 101 &&
					that.charAt(3) == 97 &&
					that.charAt(4) == 107 &&
					that.isSpace(5)
			{
				that.next(5)

				return Token.BREAK
			}
		}
		// class, const, continue
		else if c == 0'c'
		{
			if	that.charAt(1) == 108 &&
				that.charAt(2) == 97 &&
				that.charAt(3) == 115 &&
				that.charAt(4) == 115 &&
				that.isSpace(5)
			{
				that.next(5)

				return Token.CLASS
			}
			else if	that.charAt(1) == 0'o' &&
				that.charAt(2) == 0'n' &&
				that.charAt(3) == 0's' &&
				that.charAt(4) == 0't' &&
				that.isSpace(5)
			{
				that.next(5)

				return Token.CONST
			}
			else if	that.charAt(1) == 111 &&
				that.charAt(2) == 110 &&
				that.charAt(3) == 116 &&
				that.charAt(4) == 105 &&
				that.charAt(5) == 110 &&
				that.charAt(6) == 117 &&
				that.charAt(7) == 101 &&
				that.isSpace(8)
			{
				that.next(8)

				return Token.CONTINUE
			}
		}
		// do
		else if	c == 100
		{
			if 	that.charAt(1) == 111 &&
				that.isSpace(2)
			{
				that.next(2)

				return Token.DO
			}
		}
		// enum
		else if c == 101
		{
			if	that.charAt(1) == 110 &&
				that.charAt(2) == 117 &&
				that.charAt(3) == 109 &&
				that.isSpace(4)
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
				that.isSpace(3)
			{
				that.next(3)

				return Token.FOR
			}
			else if that.charAt(1) == 117 &&
				that.charAt(2) == 110 &&
				that.charAt(3) == 99 &&
				that.isSpace(4)
			{
				that.next(4)

				return Token.FUNC
			}
			else if that.charAt(1) == 105 &&
				that.charAt(2) == 110 &&
				that.charAt(3) == 97 &&
				that.charAt(4) == 108 &&
				that.isSpace(5)
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
				that.isSpace(11)
			{
				that.next(11)

				return Token.FALLTHROUGH
			}
		}
		// if, impl, import
		else if c == 105
		{
			if	that.charAt(1) == 102 &&
				that.isSpace(2)
			{
				that.next(2)

				return Token.IF
			}
			else if that.charAt(1) == 109 &&
				that.charAt(2) == 112 &&
				that.charAt(3) == 108 &&
				that.isSpace(4)
			{
				that.next(4)

				return Token.IMPL
			}
			else if that.charAt(1) == 109 &&
				that.charAt(2) == 112 &&
				that.charAt(3) == 111 &&
				that.charAt(4) == 114 &&
				that.charAt(5) == 116 &&
				that.isSpace(6)
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
				that.isSpace(8)
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
				that.isSpace(5)
			{
				that.next(5)

				return Token.MACRO
			}
			else if that.charAt(1) == 97 &&
				that.charAt(2) == 116 &&
				that.charAt(3) == 99 &&
				that.charAt(4) == 104 &&
				that.isSpace(5)
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
				that.isSpace(9)
			{
				that.next(9)

				return Token.NAMESPACE
			}
		}
		// pass
		else if c == 112
		{
			if	that.charAt(1) == 97 &&
				that.charAt(2) == 115 &&
				that.charAt(3) == 115 &&
				that.isSpace(4)
			{
				that.next(4)

				return Token.PASS
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
				that.isSpace(6)
			{
				that.next(6)

				return Token.REPEAT
			}
			else if	that.charAt(1) == 101 &&
				that.charAt(2) == 116 &&
				that.charAt(3) == 117 &&
				that.charAt(4) == 114 &&
				that.charAt(5) == 110 &&
				that.isSpace(6)
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
				that.isSpace(6)
			{
				that.next(6)

				return Token.SEALED
			}
			else if pMode ~~ ParserMode.InlineStatement &&
				that.charAt(1) == 101 &&
				that.charAt(2) == 116 &&
				that.isSpace(3)
			{
				that.next(3)

				return Token.SET
			}
			else if that.charAt(1) == 116 &&
				that.charAt(2) == 114 &&
				that.charAt(3) == 117 &&
				that.charAt(4) == 99 &&
				that.charAt(5) == 116 &&
				that.isSpace(6)
			{
				that.next(6)

				return Token.STRUCT
			}
		}
		// throw, try, tuple, type
		else if c == 0't'
		{
			if	that.charAt(1) == 104 &&
				that.charAt(2) == 114 &&
				that.charAt(3) == 111 &&
				that.charAt(4) == 119 &&
				that.isSpace(5)
			{
				that.next(5)

				return Token.THROW
			}
			else if that.charAt(1) == 114 &&
				that.charAt(2) == 121 &&
				that.isSpace(3)
			{
				that.next(3)

				return Token.TRY
			}
			else if	that.charAt(1) == 117 &&
				that.charAt(2) == 112 &&
				that.charAt(3) == 108 &&
				that.charAt(4) == 101 &&
				that.isSpace(5)
			{
				that.next(5)

				return Token.TUPLE
			}
			else if that.charAt(1) == 121 &&
				that.charAt(2) == 112 &&
				that.charAt(3) == 101 &&
				that.isSpace(4)
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
				that.isSpace(6)
			{
				that.next(6)

				return Token.UNLESS
			}
			else if	that.charAt(1) == 110 &&
				that.charAt(2) == 116 &&
				that.charAt(3) == 105 &&
				that.charAt(4) == 108 &&
				that.isSpace(5)
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
				that.isSpace(3)
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
				that.isSpace(5)
			{
				that.next(5)

				return Token.WHILE
			}
			else if	that.charAt(1) == 105 &&
				that.charAt(2) == 116 &&
				that.charAt(3) == 104 &&
				that.isSpace(4)
			{
				that.next(4)

				return Token.WITH
			}
		}

		return Token.INVALID
	} # }}}
	func TEMPLATE(that: Scanner, mut index: Number, eMode: ExpressionMode?, fMode: FunctionMode?, pMode: ParserMode): Token { # {{{
		var dyn c = that._data.charCodeAt(index)

		if c == 0'\\' && that._data.charCodeAt(index + 1) == 0'(' {
			that.next(2)

			return Token.TEMPLATE_ELEMENT
		}
		else if c == 0'`' {
			return Token.TEMPLATE_END
		}
		else if var match ?= regex.template.exec(that._data.substr(index)) {
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

	export *
}

class Scanner {
	private {
		@column: Number			= 1
		@data: String
		@eof: Boolean			= false
		@index: Number			= 0
		@line: Number			= 1
		@length: Number
		@nextColumn: Number		= 1
		@nextIndex: Number		= 0
		@nextLine: Number		= 1
	}
	constructor(@data) { # {{{
		@length = @data.length
	} # }}}
	charAt(d: Number): Number => @data.charCodeAt(@index + d)
	char(): String => @eof ? 'EOF' : @data[@index]
	column(): valueof @column
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
		return Position.new(
			line: @nextLine
			column: @nextColumn
		)
	} # }}}
	eof(): Token { # {{{
		@eof = true

		return Token.EOF
	} # }}}
	index(): valueof @index
	isBoundary(d: Number): Boolean { # {{{
		var c = @data.charCodeAt(@index + d)

		return c == 9 || c == 10 || c == 13 || c == 32 || !((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 36)
	} # }}}
	isEOF(): valueof @eof
	isSpace(d: Number): Boolean { # {{{
		var c = @data.charCodeAt(@index + d)

		return c == 9 || c == 10 || c == 13 || c == 32
	} # }}}
	line(): valueof @line
	mark(): Marker { # {{{
		return Marker.new(
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
				if token.scan(this, c) {
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
				if token.scan(this, c) {
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
		return Range.new(
			start: Position.new(
				line: @line
				column: @column
			)
			end: Position.new(
				line: @nextLine
				column: @nextColumn
			)
		)
	} # }}}
	position(start: Number): Range { # {{{
		return Range.new(
			start: Position.new(
				line: @line
				column: @column + start
			)
			end: Position.new(
				line: @nextLine
				column: @nextColumn
			)
		)
	} # }}}
	position(start: Number, length: Number): Range { # {{{
		return Range.new(
			start: Position.new(
				line: @line
				column: @column + start
			)
			end: Position.new(
				line: @line
				column: @column + start + length
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
			else if c == 0'#' {
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

				if c == 0'{' {
					if @data.charCodeAt(index + 2) != 123 && @data.charCodeAt(index + 3) != 123 {
						@nextIndex = @index = oldIndex
						@nextColumn = @column
						@nextLine = @line

						return 35
					}

					index += 2
				}
				else if c == 0'}' {
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
			else if c == 0'/' {
				c = @data.charCodeAt(index + 1)

				if c == 0'*' {
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
						else if c == 0'*' && @data.charCodeAt(index + 1) == 0'/' {
							left -= 1

							if left == 0 {
								index += 1
								column += index - lineIndex

								break
							}
						}
						else if c == 0'/' && @data.charCodeAt(index + 1) == 0'*' {
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
				else if c == 0'/' {
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
			else if c == 0'/' {
				c = @data.charCodeAt(index + 1)

				if c == 0'*' {
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
						else if c == 0'*' && @data.charCodeAt(index + 1) == 0'/' {
							left -= 1

							if left == 0 {
								index += 1
								column += index - lineIndex

								break
							}
						}
						else if c == 0'/' && @data.charCodeAt(index + 1) == 0'*' {
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
				else if c == 0'/' {
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
			else if c == 0'#' {
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

				if c == 0'{' {
					if @data.charCodeAt(index + 2) != 123 && @data.charCodeAt(index + 3) != 123 {
						@nextIndex = @index = oldIndex
						@nextColumn = @column
						@nextLine = @line

						return 35
					}

					index += 2
				}
				else if c == 0'}' {
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
			else if c == 0'/' {
				c = @data.charCodeAt(index + 1)

				if c == 0'*' {
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
						else if c == 0'*' && @data.charCodeAt(index + 1) == 0'/' {
							left -= 1

							if left == 0 {
								index += 1

								column += index - lineIndex

								break
							}
						}
						else if c == 0'/' && @data.charCodeAt(index + 1) == 0'*' {
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
				else if c == 0'/' {
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
		return Position.new(
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

			return token.scan(this, c)
		}
	} # }}}
	testNS(token: Token): Boolean { # {{{
		if @eof {
			return Token.EOF == token
		}
		else {
			return token.scan(this, @data.charCodeAt(@index))
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
		var data = @data.substring(@index, @nextIndex)

		match token {
			.CLASS_VERSION {
				return data.split('.')
			}
			.STRING {
				return data.slice(1, -1).replace(/(^|[^\\])\\('|")/g, '$1$2')
			}
			else {
				return data
			}
		}
	} # }}}
}
