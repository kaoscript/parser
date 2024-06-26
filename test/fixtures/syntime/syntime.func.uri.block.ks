class URI {
	syntime func {
		register(scheme: String, meta: String = 'hier_part [ "?" query ] [ "#" fragment ]') {
			import '@zokugun/test-import'

			var name = `\(scheme[0].toUpperCase())\(scheme.substr().toLowerCase())URI`

			quote {
				class #w(name) extends URI {
					private {
						_e: Number	= #(PI)
					}
				}
			}
		}
	}
}

URI.register('file', '[ "//" [ host ] ] path_absolute')