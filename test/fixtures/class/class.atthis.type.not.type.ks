class Greetings {
	private {
		@message: String
	}
	constructor() {
		this('Hello!')
	}
	constructor(@message: String)
	message(): @message
	message(@message): this
}