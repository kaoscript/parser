match person {
	.Teacher => "Hey Professor!"
	.Director => "Hello Director."
	.Student when .name == "Richard" => "Still here Ricky?"
	.Student => `Hey, \(.name).`
}