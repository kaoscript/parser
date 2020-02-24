enum Weekday {
	MONDAY
	TUESDAY
	WEDNESDAY
	THURSDAY
	FRIDAY
	SATURDAY
	SUNDAY

	internal isWeekend(): Boolean => this == SATURDAY + SUNDAY
}