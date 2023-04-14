tuple Pair [
	x: String	= ''
	y: Number	= 0
]

var dyn pair = Pair('x', 0.1)

console.log(pair.x, pair.y)

var dyn pair2 = Pair(y: 0.1)

console.log(pair2.x, pair2.y)