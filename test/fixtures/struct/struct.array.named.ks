struct Pair [
	x: String	= ''
	y: Number	= 0
]

let pair = new Pair('x', 0.1)

console.log(pair.x, pair.y)

let pair2 = new Pair(y: 0.1)

console.log(pair2.x, pair2.y)