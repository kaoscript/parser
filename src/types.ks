type Event<T> = {
	variant ok: Boolean {
		false, N {
			expecteds: String[]?
			start: Position?
			end: Position?
		}
		true, Y {
			value: T
			start: Position
			end: Position
		}
	}
}

type Marker = {
	eof: Boolean
	index: Number
	line: Number
	column: Number
}
