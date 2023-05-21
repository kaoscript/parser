extern {
	func parseInt(value: String): Number
}

func getSupervisorId(enteredId: String?): Number? {
	return (Number.isFinite(_) ? _ : null) <| parseInt ?<| enteredId ?? 0
}