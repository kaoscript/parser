func foo(x, y) {
	match x {
		-1 => 0
		42 => return y if y == 0
		else => return x * y
	}
}