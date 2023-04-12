namespace qux {
	class Foobar {
		private {
			_name: String
		}
		constructor(@name = 'john')
	}
}

var x = qux.Foobar.new()