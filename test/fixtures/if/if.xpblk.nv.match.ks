func foobar(x, y) {
	var name = if x {
		set match y {
			0 => 'zero'
			1 => 'one'
			else => 'bye'
		}
	}
	else {
		set 'bye'
	}
}