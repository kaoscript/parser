require Color: class, Space: enum

impl Color {
	private _luma: int
	
	luma(): int => @luma
	
	luma(@luma: int) => this
}

export Color, Space