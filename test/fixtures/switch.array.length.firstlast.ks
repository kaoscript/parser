let v = [1, 2, 3]

switch v {
	with [first, ...]	=> console.log(first) // <- 1
	with [..., last]	=> console.log(last) // <= 3
						=> console.log("empty")
}