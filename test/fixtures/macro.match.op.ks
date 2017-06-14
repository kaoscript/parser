macro match_tokens {
	(a + b) => 'any'
	(a: Identifier + b: Identifier) => 'identifier'
	(a: Number + b: Number) => 'number'
	(a + b + c + d) => 'polyadic'
	(a + b, c + d) => 'list'
}