extern console

namespace Float {
	func toString(value: Number): String => value.toString()
}

console.log(`\(Float.toString(3.14))`)