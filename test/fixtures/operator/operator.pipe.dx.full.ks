async func process(input) {
	return input
		|> await preprocess(_)
		|> _.next()
		|> ({x, y, ...z}) => Foo.new(x, y, z)
		|> _.log()
}