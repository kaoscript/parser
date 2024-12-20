syntime {
	macro match_tokens(a) => quote 'any'
	macro match_tokens(a: Identifier) => quote 'identifier'
	macro match_tokens(a: Number) => quote 'number'
}