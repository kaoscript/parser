class URI {
	macro register(scheme: String, meta: String = 'hier_part [ "?" query ] [ "#" fragment ]') {
		import * from @zokugun/test-import
		
		const name = `\(scheme[0].toUpperCase())\(scheme.substr().toLowerCase())URI`
		
		macro {
			class $i{name} extends URI {
				private {
					_e: Number	= $v{PI}
				}
			}
		}
	}
}

URI.register!('file', '[ "//" [ host ] ] path_absolute')