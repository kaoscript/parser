class Greetings {
	private {
		_message: string = ''
	}
	
	Greetings() {
		this('Hello!')
	}
	
	Greetings(@message)
	
	greet(name: string): string {
		return this._message + '\nIt\'s nice to meet you, ' + name + '.'
	}
}

let hello = new Greetings('Hello world!')

expect(hello.greet('miss White')).to.equal('Hello world!\nIt\'s nice to meet you, miss White.')