class Shape {
	private {
		_color: string = ''
	}
	
	constructor(@color)
	
	color(): string => this._color
	
	color(@color): Shape => this
	
	color(shape: Shape): Shape {
		this._color = shape.color()
		
		return this
	}
}