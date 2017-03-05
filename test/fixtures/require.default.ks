require Color: class, Space: enum

impl Color {
	private _luma: int
	
	luma(): int => @luma
	
	luma(@luma) => this
}

export Color, Space