func foo(x, y) {
	switch x {
		-1 => 0
		42 => return y
		=> return x * y
	}
}