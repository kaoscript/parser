func foobar(writer, w, q, h, next) {
	next(
		writer
			.code('?') if q
			.code('|>')
			.code('#') if h
			.code(' ')
	)
}