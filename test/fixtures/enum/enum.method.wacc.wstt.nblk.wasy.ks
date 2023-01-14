enum Weekday {
	MONDAY
	TUESDAY
	WEDNESDAY
	THURSDAY
	FRIDAY
	SATURDAY
	SUNDAY

	internal static async fromString(value: String): Weekday? {
			match value {
				'monday' => return MONDAY
			}

			return null
		}
}