var dyn foobar = {
	foo(name: string) {
		n = 0
	}
	async bar(name: string) {
		n = 0
	}
	reverse(value: String): String => value.split('').reverse().join('')
	reverse(value: Array): Array => value.slice().reverse()
	async reverseAsync(value: String): String => value.split('').reverse().join('')
	async reverseAsync(value: Array): Array => value.slice().reverse()
}