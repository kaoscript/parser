match fg {
	.BLACK		=> fg_code = 30
	.RED		=> fg_code = 31
	.GREEN		=> fg_code = 32
	.YELLOW		=> fg_code = 33
	.BLUE		=> fg_code = 34
	.MAGENTA	=> fg_code = 35
	.CYAN		=> fg_code = 36
	.WHITE		=> fg_code = 37
	else		=> fg_code = 39
}