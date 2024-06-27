class Color {
	syntime func registerSpace(data: Object) {
		if ?data.components {
			var fields: Array<Expr> = []
			var methods: Array<Expr> = []

			var dyn field
			for name, component in data.components {
				field = `_\(name)`

				fields.push(quote private #w(field): #w(component.type))

				methods.push(quote {
					#w(name)() => this.getField(#(name))
					#w(name)(value) => this.setField(#(name), value)
				})

				data.components[name].field = field
			}

			quote {
				Color.registerSpace(#(data))

				impl Color {
					#s(fields)
					#s(methods)
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