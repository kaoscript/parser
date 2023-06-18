type Pair = [ String, Number ]

tuple Triple implements Pair [ :String, :Number, :Boolean ]

var triple = Triple('x', 0.1, true)

console.log(triple.0, triple.1, triple.2)