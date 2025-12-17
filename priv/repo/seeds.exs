alias TokenManagementService.Repo
alias TokenManagementService.Tokens.Schemas.Token

now = DateTime.utc_now()

tokens =
  Enum.map(1..100, fn _ ->
    %{
      status: "available",
      last_activated_at: nil,
      inserted_at: now,
      updated_at: now
    }
  end)

Repo.insert_all(Token, tokens)

IO.puts("Seeded 100 available tokens")
