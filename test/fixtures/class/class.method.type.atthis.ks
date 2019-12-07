class Foobar {
	private {
		@value: Number	= 42
	}
	value(): @value
	value(@value): Foobar => this
}