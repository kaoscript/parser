export class Color {
	getField(name) ~ Error {
		throw Error.new('Not Implemented')
	}

	setField(name, value) ~ Error {
		throw Error.new('Not Implemented')
	}
}

syntime impl Color {
	 registerSpace(expression: Object) {
		if ?expression.components {
			var fields: Array = []
			var methods: Array = []

			var dyn field
			for component, name of expression.components {
				field = `_\(name)`

				fields.push(quote private #(field): #(component.type))

				methods.push(quote {
					#[error(off)]
					#(name)() => this.getField(#v(name))
					#[error(off)]
					#(name)(value) => this.setField(#v(name), value)
				})

				expression.components[name].field = field
			}

			quote {
				Color.registerSpace(#(expression))

				impl Color {
					#b(fields)
					#b(methods)
				}
			}
		}
		else {
			quote Color.registerSpace(#(expression))
		}
	}
}

Color.registerSpace({
	name: 'srgb'
	alias: ['rgb']
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