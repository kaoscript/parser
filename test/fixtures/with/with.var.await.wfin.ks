with var file = await open() {
	var text = await file.readText()
}
finally {
	file.close()
}