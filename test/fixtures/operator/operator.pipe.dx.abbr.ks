async func process(input) {
	return input
		|> preprocess
		|> await
		|> .next()
		|> ({x, y, ...z}) => Foo.new(x, y, z)
		|> .log()
}