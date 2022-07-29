var dyn a = [
	"Hydrogen",
	"Helium",
	"Lithium",
	"Beryl­lium"
]

var dyn a2 = a.map(func(s) {
	return s.length
})

var dyn a3 = a.map((s) => {
	return s.length
})

var dyn a3 = a.map(func(s) => s.length)

var dyn a4 = a.map((s) => s.length)

var dyn a5 = a.map(s => s.length)