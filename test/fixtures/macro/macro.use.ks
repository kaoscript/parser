macro using_a(a: Identifier, e: Expression) {
	macro {
		(() => {
			let #a = 42
			return #e
		})()
	}
}

let four = using_a!(a, a / 10)