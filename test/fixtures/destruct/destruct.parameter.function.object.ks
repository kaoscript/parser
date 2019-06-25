func foo({x, y, z}) {

}

func foo({x = 1, y = 2, z = 3}: {x: Number, y: Number, z: Number} = {}) {

}

func foo({x: a = 1, y: b = 2, z: c = 3}: Object<Number> = {}) {

}

func foo({x, y, ...z}) {

}

func foo({name, scores: {x = 0, y = 0, z = 0} = {}} = {}) {

}

const foo = ({x, y, z} = {x: 1, y: 2, z: 3}) => [x, y, z]