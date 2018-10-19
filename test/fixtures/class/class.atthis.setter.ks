class Greetings {
	private {
		_message: string = ''
	}
	
	constructor() {
		this('Hello!')
	}
	
	constructor(@message())
	
	greet(name: string): string {
		return @message + '\nIt\'s nice to meet you, ' + name + '.'
	}
}