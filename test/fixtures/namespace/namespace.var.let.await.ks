extern console

async func min() => 'female'

namespace foo {
	var mut gender: String = await min()
}

console.log(`\(foo.gender)`)