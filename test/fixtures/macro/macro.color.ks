class Color {
	macro registerSpace(@data: Object) {
		if data.components? {
			const fields: Array<Expr> = []
			const methods: Array<Expr> = []
			
			let field
			for name, component in data.components {
				field = `_\(name)`
				
				fields.push(macro private #i(field): Number)
				
				methods.push(macro {
					#i(name)() => this.getField(#(name))
					#i(name)(value) => this.setField(#(name), value)
				})
				
				data.components[name].field = field
			}
			
			macro {
				Color.registerSpace(#(data))
				
				impl Color {
					#b(fields)
					#b(methods)
				}
			}
		}
		else {
			macro Color.registerSpace(#(data))
		}
	}
}

Color.registerSpace!({
	name: Space::SRGB
	alias: [Space::RGB]
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