func foo(bar: string, qux: int) async: string {
	return bar + '+' + qux
}

func bar(callback) {
	let text = await foo('foobar', 42)
	
	callback(null, text)
}