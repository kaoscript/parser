enum Weekday {
	MONDAY
	TUESDAY
	WEDNESDAY
	THURSDAY
	FRIDAY
	SATURDAY
	SUNDAY

	public static {
		fromString(value: String): Weekday? {
			switch value {
				'monday' => return MONDAY
			}

			return null
		}
	}
}