class Greetings {
	private {
		@message: String
	}
	constructor([@message: String]) {
		this.message(message)
	}
	message(): @message
	message(@message): this
}