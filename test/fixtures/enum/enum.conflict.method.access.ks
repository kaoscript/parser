enum Foobar1 {
	internal() => false
	private() => false
	public() => false
}

enum Foobar2 {
	internal internal() => false
	private private() => false
	public public() => false
}

enum Foobar3 {
	static internal() => false
	static private() => false
	static public() => false
}