syntime macro match_tokens(a) => quote 'any'
syntime macro match_tokens(a: Identifier) => quote 'identifier'
syntime macro match_tokens(a: Number) => quote 'number'