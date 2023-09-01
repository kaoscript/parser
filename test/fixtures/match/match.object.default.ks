var value = {
	foo: 1,
	bar: func() => 2
}

match value {
	{foo: 1}	with {qux % n} 			=> console.log(`qux: \(n)`)
	{foo: 1} 							=> console.log('foo: 1')
	{foo}								=> console.log('has foo')
	{qux}								=> console.log('has qux')
				when value.bar() == 0	=> console.log('bar() == 0')
	else								=> console.log('oops!')
}