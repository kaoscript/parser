export class Color {
	macro registerSpace(@expression: Object) {
		if ?expression.components {
			var fields: Array = []
			var methods: Array = []

			var dyn field
			for component, name of expression.components {
				field = `_\(name)`

				fields.push(macro private #w(field): #w(component.type))

				methods.push(macro {
					#[error(off)]
					#w(name)() => this.getField(#(name))
					#[error(off)]
					#w(name)(value) => this.setField(#(name), value)
				})

				expression.components[name].field = field
			}

			macro {
				Color.registerSpace(#(expression))

				impl Color {
					#s(fields)
					#s(methods)
				}
			}
		}
		else {
			macro Color.registerSpace(#(expression))
		}
	}

	getField(name) ~ Error {
		throw Error.new('Not Implemented')
	}

	setField(name, value) ~ Error {
		throw Error.new('Not Implemented')
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