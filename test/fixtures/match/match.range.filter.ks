var dyn temperature = 54

match temperature {
	0..49 	when temperature % 2 == 0	=> console.log("Cold and even")
	50..79	when temperature % 2 == 0	=> console.log("Warm and even")
	80..110	when temperature % 2 == 0	=> console.log("Hot and even")
	else								=> console.log("Temperature out of range or odd")
}