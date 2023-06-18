type Point = {
	x: Number
	y: Number
}

struct Point3D implements Point {
	x: Number
	y: Number
	z: Number
}

var dyn point = Point3D(0.3, 0.4, 0.5)

console.log(point.x, point.y, point.z)