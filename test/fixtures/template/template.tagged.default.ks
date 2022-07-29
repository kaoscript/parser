var dyn person = 'Mike'
var dyn age = 28

func myTag(strings, personExp, ageExp) {
	var str0 = strings[0]
	var str1 = strings[1]

	var dyn ageStr
	if ageExp > 99 {
		ageStr = 'centenarian'
	}
	else {
		ageStr = 'youngster'
	}

	return `\(str0)\(personExp)\(str1)\(ageStr)`
}

var output = myTag`That \( person ) is a \( age )`

console.log(output + 12)

console.log(myTag`That \( person ) is a \( age )`)