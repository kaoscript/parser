elements
  |> map(_, add^^(^, 1))
  |> filter(_, greaterThan^^(^, 5))