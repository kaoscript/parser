var dyn somePoint = [1, 1]

switch somePoint {
	[0, 0]						=> console.log("(0, 0) is at the origin")
	[_, 0]			with [x, _]	=> console.log("(\(x), 0) is on the x-axis")
	[0, _]			with [_, y]	=> console.log("(0, \(y)) is on the y-axis")
	[-2..2, -2..2]	with [x, y]	=> console.log("(\(x), \(y)) is inside the box")
	_				with [x, y]	=> console.log("(\(x), \(y)) is outside of the box")
	_							=> console.log("Not a point")
}