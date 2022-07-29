func f1(foo) {
	return 42
}

var dyn f2 = func(foo) {
	return 42
}

var dyn f3 = (foo) => {
	return 42
}

var dyn f4 = (foo) => 42

var dyn f5 = func(foo) => 42

var dyn f6 = foo => 42