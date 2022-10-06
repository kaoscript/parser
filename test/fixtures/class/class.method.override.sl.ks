class Foobar {
	foobar(x: Number): String {
		return `\(x)`
	}
}

class Quxbaz extends Foobar {
	override foobar(x) {
		return ''
	}
}