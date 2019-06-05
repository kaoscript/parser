likes = {
	leto: 'spice'
	paul: 'chani'
	duncan: 'murbella'
}

for value, key of likes until key == 'duncan' {
	console.log(`\(key) likes \(value)`)
}