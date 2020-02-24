enum Weekday {
	MONDAY
	TUESDAY
	WEDNESDAY
	THURSDAY
	FRIDAY
	SATURDAY
	SUNDAY

	static async fromString(value: String): Weekday? {
		switch value {
			'monday' => return MONDAY
		}

		return null
	}
}