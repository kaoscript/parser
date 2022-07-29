namespace qux {
	class Foobar {
		private {
			_name: String
		}
		constructor(@name = 'john')
	}
}

var x = new qux.Foobar()