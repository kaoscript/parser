extern console

async func min() => 'female'

namespace foo {
	var dyn gender: String = await min()
}

console.log(`\(foo.gender)`)