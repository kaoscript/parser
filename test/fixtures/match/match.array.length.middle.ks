var dyn v = [1, 2, 3, 4, 5]

match v {
	with [first, ...middle, last]	=> console.log(first, middle, last) // <- 1, [2, 3, 4], 5
	else							=> console.log("empty")
}