var newScore = person.score
  |> double
  |> add(7, _)
  |> boundScore(0, 100, _)