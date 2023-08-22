class Greetings {
	private {
		@message: String
	}
	constructor({message}: {message: String}) {
		this.message(message)
	}
	message() :> @message
	message(@message) :> this
}



class Greetings {
	private {
		@message: String
	}
	constructor({message}: {message: String}) {
		this.message(message)
	}
	message(): auto => @message
	message(@message): auto => this
}