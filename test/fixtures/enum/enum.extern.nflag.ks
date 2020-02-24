extern enum CardSuit {
	Clubs
	Diamonds
	Hearts
	Spades

	static fromString(value: String): CardSuit?
}