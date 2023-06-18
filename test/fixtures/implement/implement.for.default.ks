type Shape = {
	draw(): String
}

class Rectangle {
}

impl Shape for Rectangle {
	override draw() {
		return 'rectangle'
	}
}