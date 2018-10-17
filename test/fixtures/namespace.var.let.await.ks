extern console

async func min() => 'female'

namespace foo {
	let gender: String = await min()
}

console.log(`\(foo.gender)`)