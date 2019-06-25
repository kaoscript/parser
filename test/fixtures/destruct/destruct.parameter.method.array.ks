class Foobar {
	foo([x, y, z]) {

	}

	foo([x: Number = 1, y: Number = 2, z: Number = 3] = []) {

	}

	foo([x = 1, y = 2, z = 3]: [Number, Number, Number] = []) {

	}

	foo([x = 1, y = 2, z = 3]: Array<Number> = []) {

	}

	foo([x, y, ...z]) {

	}

	foo([, y, ...]) {

	}

	foo([name, [x = 0, y = 0, z = 0] = []] = []) {

	}

	foo([@x, [@y, [@z]]]) {

	}
}