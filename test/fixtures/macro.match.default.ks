macro match_tokens {
	(a + b) => 'got an addition'
	(i: Identifier) => 'got an identifier'
	(...others) => 'got something else'
}