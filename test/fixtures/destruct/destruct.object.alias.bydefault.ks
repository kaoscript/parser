let foo = { bar: 'hello', baz: 3 }

let {bar: a = 'bar', baz: b = 'baz'} = foo

console.log(a)
// <- 'hello'

console.log(b)
// <- 3