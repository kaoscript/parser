class Foobar {
	private {
		@value: Number	= 42
	}
	value(): auto => @value
	value(@value): Foobar => this
}