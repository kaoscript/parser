likes = {
	leto: 'spice'
	paul: 'chani'
	duncan: 'murbella'
}

for value, key of likes when isFremen(key) {
	console.log(`\(key) likes \(value)`)
}