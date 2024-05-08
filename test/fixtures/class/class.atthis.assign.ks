class Greetings {
	private {
		_message: String = ''
	}

	constructor(message: String?) {
		@message = if message == null set 'Hello!' else message
	}
}