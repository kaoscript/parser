import 'chevrotain' {
	func createToken
	sealed class Lexer
	sealed class Parser
	sealed class Token
} for {
	createToken => createChevrotainToken
	Lexer => ChevrotainLexer
	Parser => ChevrotainParser
	Token => ChevrotainToken
}