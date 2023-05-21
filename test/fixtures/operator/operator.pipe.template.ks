promise
  |> await
  |> doubleSay(_, ', ')
  |> capitalize
  |> `\(_)!`
  |> User.Message.new
  |> stream.write
  |> await
  |> console.log