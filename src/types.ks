struct Event {
	ok: Boolean
	value?				= null
	start: Position?	= null
	end: Position?		= null
}

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

struct Range {
	start: Position
	end: Position
}
