class Foobar {
	private {
		@x: Number
		@y: Number
	}
	constructor(fn) {
		fn((@x, @y) => {
		})
	}
}