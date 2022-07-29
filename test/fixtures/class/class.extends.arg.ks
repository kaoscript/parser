class Shape {
	protected {
		_color: string = ''
	}

	constructor(@color)

	draw(canvas): string {
		throw new Error('Not Implemented')
	}
}

class Rectangle extends Shape {
	constructor(@color)

	draw(canvas): string {
		return 'I\'m drawing a ' + this._color + ' rectangle.'
	}
}

var r = new Rectangle('black')

expect(r.draw()).to.equal('I\'m drawing a black rectangle.')