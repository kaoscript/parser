var dyn v = [1, 2, 3]

match v {
	with [first, ...]	=> console.log(first) // <- 1
	with [..., last]	=> console.log(last) // <= 3
	else				=> console.log("empty")
}