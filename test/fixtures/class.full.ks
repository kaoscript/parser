class Shape {
	private {
		_color: string = ''
	}
	
	Shape(@color)
	
	color(): string => this._color
	
	color(@color): Shape => this
	
	color(shape: Shape): Shape {
		this._color = shape.color()
		
		return this
	}
}