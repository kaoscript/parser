class URI {
	at syntime {
		var ast = register('file', '[ "//" [ host ] ] path_absolute')

		echo(ast)

		quote ast
	}
}