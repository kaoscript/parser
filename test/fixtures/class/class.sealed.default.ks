sealed class Greetings {
	private {
		_message: String = ''
	}
	
	constructor() {
		this('Hello!')
	}
	
	constructor(@message)
	
	greet(name: String) {
		return `\(@message)\nIt's nice to meet you\(name).`
	}
}