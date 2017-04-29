class Color {
	macro {
		registerSpace(expression: Object) {
			if expression.components? {
				const fields: Array<Expr> = []
				const methods: Array<Expr> = []
				
				let field
				for name, component in expression.components {
					field = `_\(name)`
					
					fields.push(macro private $i{field}: Number)
					
					methods.push(macro {
						$i{name}() => this.getField($v{name})
						$i{name}(value) => this.setField($v{name}, value)
					})
					
					expression.components[name].field = field
				}
				
				macro {
					Color.registerSpace($v{expression})
					
					impl Color {
						$b{fields}
						$b{methods}
					}
				}
			}
			else {
				macro Color.registerSpace($v{expression})
			}
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