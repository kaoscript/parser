class Shape {
	private {
		_color: string = ''
		_type: string = ''
	}
	
	static {
		makeRectangle(color: string): Shape => new Shape('rectangle', color)
	}
	
	Shape(@type: string, @color: string)
}

let r = Shape.makeRectangle('black')

expect(r.type).to.equal('rectangle')
expect(r.color).to.equal('black')