alias TokenManagementService.Repo
alias TokenManagementService.Tokens.Schemas.Token

existing_count = Repo.aggregate(Token, :count, :id)

if existing_count == 0 do
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
else
  IO.puts("Skipped seeding: #{existing_count} tokens already present")
end
