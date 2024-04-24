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




// type Result<V, E> = {
// 	variant ok: Boolean {
// 		false, Err {
//			expecteds: Null
// 			start: Null
// 			end: Null
//		} | {
// 			expecteds: String[]
// 			start: Position
// 			end: Position
// 		}
// 		true, Ok {
// 			value: V
// 			start: Position
// 			end: Position
// 		}
// 	}
// }
