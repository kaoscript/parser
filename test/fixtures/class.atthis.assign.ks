class Greetings {
	private {
		_message: String = ''
	}
	
	constructor(message: String?) {
		@message = message == null ? 'Hello!' : message
	}
}