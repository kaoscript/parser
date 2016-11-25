class Shape {
	protected {
		_color: string = ''
	}
	
	Shape(@color: string)

	draw(canvas): string {
		throw new Error('Not Implemented')
	}
}

class Rectangle extends Shape {
	Rectangle(@color: string)

	draw(canvas): string {
		return 'I\'m drawing a ' + this._color + ' rectangle.'
	}
}

let r = new Rectangle('black')

expect(r.draw()).to.equal('I\'m drawing a black rectangle.')