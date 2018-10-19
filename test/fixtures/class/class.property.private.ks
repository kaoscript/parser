class Vector {
	private _x: Number
	public x: Number {
		get {
			return this._x
		}
		set {
			this._x = Math.abs(x)
		}
	}
}