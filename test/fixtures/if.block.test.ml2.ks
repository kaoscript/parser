if	!arrow &&
	(
		(rest != -1 && !fr && (db == 0 || db + 1 == rest)) ||
		(
			rest == -1 &&
			(
				(!signature.async && signature.max == l && (db == 0 || db == l)) ||
				(signature.async && signature.max == l + 1 && (db == 0 || db == l + 1))
			)
		)
	)
{
}