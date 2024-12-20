class Color {
}

syntime impl Color {
	registerSpace(data: Object) {
		if ?data.components {
			var fields: Array<Expr> = []
			var methods: Array<Expr> = []

			var dyn field
			for name, component in data.components {
				field = `_\(name)`

				fields.push(quote private #(field): #(component.type))

				methods.push(quote {
					#(name)() => this.getField(#v(name))
					#(name)(value) => this.setField(#v(name), value)
				})

				data.components[name].field = field
			}

			quote {
				Color.registerSpace(#(data))

				impl Color {
					#b(fields)
					#b(methods)
				}
			}
		}
		else {
			quote Color.registerSpace(#(data))
		}
	}
}

Color.registerSpace({
	name: Space.SRGB
	alias: [Space.RGB]
	components: {
		red: {
			max: 255
		}
		green: {
			max: 255
		}
		blue: {
			max: 255
		}
	}
})