struct Marker {
	eof: Boolean
	index: Number
	line: Number
	column: Number
}

struct Position {
	line: Number
	column: Number
}

struct Event {
	ok: Boolean
	value?			= null
	start?			= null
	end?			= null
}
