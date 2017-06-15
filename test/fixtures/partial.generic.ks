import '@oz/lang'

let a : Array<number> = [1, 3, 2, 4]

console.log(a)

impl Array<number> {
	sort(): Array<number> => (this as Array).sort((a, b) => a - b)
}

console.log(a.sort())