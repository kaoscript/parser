extern console

func min() => {
	gender: 'female'
	age: 24
}

namespace foo {
	let {gender, age} = min()
}

console.log(foo.age)
console.log(`\(foo.gender)`)