let person = 'Mike'
let age = 28

func myTag(strings, personExp, ageExp) {
	const str0 = strings[0]
	const str1 = strings[1]

	let ageStr
	if ageExp > 99 {
		ageStr = 'centenarian'
	}
	else {
		ageStr = 'youngster'
	}

	return `\(str0)\(personExp)\(str1)\(ageStr)`
}

const output = myTag`That \( person ) is a \( age )`

console.log(output + 12)

console.log(myTag`That \( person ) is a \( age )`)