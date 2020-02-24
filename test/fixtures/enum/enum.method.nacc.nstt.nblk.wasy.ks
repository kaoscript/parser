enum Weekday {
	MONDAY
	TUESDAY
	WEDNESDAY
	THURSDAY
	FRIDAY
	SATURDAY
	SUNDAY

	async isWeekend(): Boolean => this == SATURDAY + SUNDAY
}