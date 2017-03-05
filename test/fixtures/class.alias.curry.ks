let black = '000000'

func $reshape(bg) {
}

class Shape {
	private {
		_color: string = ''
	}
	
	Shape(@color)
	
	reshape() as $reshape with black
}