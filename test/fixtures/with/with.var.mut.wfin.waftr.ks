with var mut file = open() {
	var text = await file.readText()
}
finally {
	file.close()
}

var mut file = open()