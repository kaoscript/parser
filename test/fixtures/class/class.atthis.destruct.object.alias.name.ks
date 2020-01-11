class Greetings {
	private {
		@message: String
	}
	constructor({@message: msg}) {
		this.message(msg)
	}
	message(): @message
	message(@message): this
}