with {
	var mut file = open()
	var mut file2 = open2()
}
then {
	var text = await file.readText()
}
finally {
	file.close()
}