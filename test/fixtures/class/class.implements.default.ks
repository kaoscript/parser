type Shape = {
	draw(): String
}

class Rectangle implements Shape {
	override draw() {
		return 'rectangle'
	}
}