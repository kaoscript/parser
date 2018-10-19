class Vector {
	public {
		x: Number { get, set }
		y: Number {
			get
			set => Math.abs(y)
		}
		z: Number {
			get => 0
		}
	}
}