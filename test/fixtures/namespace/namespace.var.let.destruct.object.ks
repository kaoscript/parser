extern console

func min() => {
	gender: 'female'
	age: 24
}

namespace foo {
	var dyn {gender, age} = min()
}

console.log(foo.age)
console.log(`\(foo.gender)`)