class Greetings {
	private {
		_message: string = ''
	}

	constructor() {
		this('Hello!')
	}

	constructor(@message)

	greet(name: string): string {
		return this._message + '\nIt\'s nice to meet you, ' + name + '.'
	}
}

var hello = Greetings.new('Hello world!')

expect(hello.greet('miss White')).to.equal('Hello world!\nIt\'s nice to meet you, miss White.')