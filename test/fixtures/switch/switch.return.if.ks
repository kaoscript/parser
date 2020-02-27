func foo(x, y) {
	switch x {
		-1 => 0
		42 => return y if y == 0
		=> return x * y
	}
}