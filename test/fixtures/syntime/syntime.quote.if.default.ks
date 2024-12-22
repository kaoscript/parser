enum Weekday {
    MONDAY      = (1, 'Monday')
    TUESDAY     = (2, 'Tuesday')
    WEDNESDAY   = (3, 'Wednesday')
    THURSDAY    = (4, 'Thursday')
    FRIDAY      = (5, 'Friday')
    SATURDAY    = (6, 'Saturday')
    SUNDAY      = (7, 'Sunday')

    const dayOfWeek: Number
    const printableName: String

	toString() {
		match this {
			at syntime {
				for var token in Weekday.values {
					quote {
						#if token.name != 'SUNDAY' {
							quote {
								.#(token.name) {
									return #v(token.printableName)
								}
							}
						}
					}
				}
			}
		}
	}
}