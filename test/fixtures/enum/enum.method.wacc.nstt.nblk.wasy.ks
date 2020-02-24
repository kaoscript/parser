enum Weekday {
	MONDAY
	TUESDAY
	WEDNESDAY
	THURSDAY
	FRIDAY
	SATURDAY
	SUNDAY

	internal async isWeekend(): Boolean => this == SATURDAY + SUNDAY
}