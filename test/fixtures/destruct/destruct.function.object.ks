func foo({x, y, z}) {
}

func foo({x = 1, y = 2, z = 3}: {x: Number, y: Number, z: Number} = {}) {
}

func foo({x % a = 1, y % b = 2, z % c = 3}: Object<Number> = {}) {
}

func foo({x % a: Number = 1, y % b: Number = 2, z % c: Number = 3} = {}) {
}

func foo({x, y, ...z}) {
}

func foo({x, y, ...}) {
}

func foo({name, scores % {x = 0, y = 0, z = 0} = {}} = {}) {
}

var foo = ({x, y, z} = {x: 1, y: 2, z: 3}) => [x, y, z]