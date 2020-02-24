enum Weekday {
	MONDAY
	TUESDAY
	WEDNESDAY
	THURSDAY
	FRIDAY
	SATURDAY
	SUNDAY

	private {
		isWeekend(): Boolean => this == SATURDAY + SUNDAY
	}
}