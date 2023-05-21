async func process(input) {
	return input
		|> (value) => await preprocess(value)
		|> (value) => value.next()
		|> ({x, y, ...z}) => Foo.new(x, y, z)
		|> value => value.log()
}