enum Token {
	Nil
}

syntime namespace Meta {
	type TokenRecipe = {
		token: Token
	}

	type TokenTree = {
		character: Number
		tokens: TokenRecipe[]
	}

	func buildTree(tree: TokenTree, level: Number) {
	}

	export macro build(name: Ast(Identifier), ...tokens: TokenRecipe) {
		quote {
			type #(name) = {
			}
		}
	}
}