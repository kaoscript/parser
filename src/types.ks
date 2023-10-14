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

type Position = {
	line: Number
	column: Number
}

type Range = {
	start: Position
	end: Position
}
