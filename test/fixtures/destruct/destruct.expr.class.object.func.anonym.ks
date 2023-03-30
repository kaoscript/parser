class Foobar {
	private {
		@x: Number
		@y: Number
	}
	constructor(fn) {
		fn(func(values) {
			{@x, @y} = values
		})
	}
}