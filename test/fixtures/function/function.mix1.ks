let a = [
	"Hydrogen",
	"Helium",
	"Lithium",
	"Beryl­lium"
]

let a2 = a.map(func(s) {
	return s.length
})

let a3 = a.map((s) => {
	return s.length
})

let a3 = a.map(func(s) => s.length)

let a4 = a.map((s) => s.length)

let a5 = a.map(s => s.length)