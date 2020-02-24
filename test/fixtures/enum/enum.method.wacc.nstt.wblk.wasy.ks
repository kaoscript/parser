enum Weekday {
	MONDAY
	TUESDAY
	WEDNESDAY
	THURSDAY
	FRIDAY
	SATURDAY
	SUNDAY

	private {
		async isWeekend(): Boolean => this == SATURDAY + SUNDAY
	}
}