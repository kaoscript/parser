abstract class Master {
	private {
		@value: String	= ''
	}
	abstract value(): typeof @value
	abstract value(@value): typeof this
}