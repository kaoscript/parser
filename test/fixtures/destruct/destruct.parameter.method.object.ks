class Foobar {
	foo({x, y, z}) {

	}

	foo({x = 1, y = 2, z = 3}: {x: Number, y: Number, z: Number} = {}) {

	}

	foo({x: a = 1, y: b = 2, z: c = 3}: Object<Number> = {}) {

	}

	foo({x, y, ...z}) {

	}

	foo({name, scores: {x = 0, y = 0, z = 0} = {}} = {}) {

	}

	foo({@x, y: {@y, z: {@z}}}) {

	}
}