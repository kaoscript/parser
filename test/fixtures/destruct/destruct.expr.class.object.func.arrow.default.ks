class Foobar {
	private {
		@x: Number
		@y: Number
	}
	constructor(fn) {
		fn(values => {
			{@x, @y} = values
		})
	}
}