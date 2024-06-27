myMacro!(if ?test {
    for var value in values {
		return null unless test(value)
	}
})