import 'chevrotain' {
	func createToken	=> createChevrotainToken
	sealed class Lexer	=> ChevrotainLexer
	sealed class Parser	=> ChevrotainParser
	sealed class Token	=> ChevrotainToken
}