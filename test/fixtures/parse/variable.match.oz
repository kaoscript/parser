// #ff0000aa
if match ?= /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/.exec(color) {
	console.log('red', Integer.parse(match[1], 16))
	console.log('green', Integer.parse(match[2], 16))
	console.log('blue', Integer.parse(match[3], 16))
	console.log('alpha', $caster.alpha(Integer.parse(match[4], 16) / 255))
}