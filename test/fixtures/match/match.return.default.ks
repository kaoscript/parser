func foo(x, y) {
	match x {
		-1 => 0
		42 => return y
		else => return x * y
	}
}