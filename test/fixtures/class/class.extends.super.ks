class Shape {
	protected {
		_color: string = ''
	}

	constructor(@color)

	draw(canvas): string {
		throw Error.new('Not Implemented')
	}
}

class Rectangle extends Shape {
	constructor(color: string) {
		super(color)
	}

	draw(canvas): string {
		return 'I\'m drawing a ' + this._color + ' rectangle.'
	}
}

var r = Rectangle.new('black')

expect(r.draw()).to.equal('I\'m drawing a black rectangle.')