class Greetings {
	private {
		_message: string = ''
	}
	
	Greetings() {
		this('Hello!')
	}
	
	Greetings(@message: string)
	
	greet(name: string): string {
		return @message + '\nIt\'s nice to meet you, ' + name + '.'
	}
}