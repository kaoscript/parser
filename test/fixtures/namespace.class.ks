namespace qux {
	class Foobar {
		private {
			_name: String
		}
		constructor(@name = 'john')
	}
}

const x = new qux.Foobar()