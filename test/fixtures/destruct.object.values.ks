let {foo=3} = { foo: 2 }

console.log(foo)
// <- 2

let {foo=3} = { foo: undefined }

console.log(foo)
// <- 3

let {foo=3} = { bar: 2 }

console.log(foo)
// <- 3