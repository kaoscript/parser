func foo([x, y, z]) {

}

func foo([x: Number = 1, y: Number = 2, z: Number = 3] = []) {

}

func foo([x = 1, y = 2, z = 3]: [Number, Number, Number] = []) {

}

func foo([x = 1, y = 2, z = 3]: Array<Number> = []) {

}

func foo([x, y, ...z]) {

}

func foo([, y, ...]) {

}

func foo([name, [x = 0, y = 0, z = 0] = []] = []) {

}

const foo = ([x, y, z] = [1, 2, 3]) => [x, y, z]