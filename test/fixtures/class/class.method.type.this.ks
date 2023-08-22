class Foobar {
	private {
		@value: Number	= 42
	}
	value(): Number => @value
	value(@value) :> this
}