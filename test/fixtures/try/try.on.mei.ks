try {
	console.log('foobar')
}
on RangeError catch error {
	console.log('RangeError', error)
}
on SyntaxError catch error {
	console.log('SyntaxError', error)
}
catch error {
	console.log('Error', error)
}