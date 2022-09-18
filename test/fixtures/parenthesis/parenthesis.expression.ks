class Foobar {
	foobar() {
		return @foobar ?? (@foobar <- foobar())
	}
}