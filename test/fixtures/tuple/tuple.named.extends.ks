tuple Pair {
	x: String	= ''
	y: Number	= 0
}

tuple Triple extends Pair {
	z: Boolean	= false
}

var triple = Triple('x', 0.1, true)

console.log(triple.x, triple.y, triple.z)