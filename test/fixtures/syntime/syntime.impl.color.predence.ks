extern t1, t2, t3, h, i

var foo = t1 + (t2 - t1) * (2 / 3 - t3) * 6
var bar = h + 1 / 3 * - (i - 1)

export class Color {
}

syntime impl Color {
	registerSpace(expression: Object) {
		quote Color.registerSpace(#(expression))
	}
}

Color.registerSpace({
	name: 'FBQ'
	formatters: {
		foo: func(t1, t2, t3) => t1 + (t2 - t1) * (2 / 3 - t3) * 6
		bar: func(h, i) => h + 1 / 3 * - (i - 1)
	}
})