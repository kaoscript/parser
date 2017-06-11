func foo(x: Number, y: Number, z?) {
	z ??= (z: Number) => [x, y, z]
	
	return z
}