defmodule TokenManagementService.TokenPool.TokenManagerTest do
  use TokenManagementService.DataCase, async: false

  alias TokenManagementService.Repo
  alias TokenManagementService.TokenPool.TokenManager
  alias TokenManagementService.TokenPool.ExpirationScheduler
  alias TokenManagementService.Tokens.Repo, as: TokensRepo
  alias TokenManagementService.Tokens.Schemas.{Token, TokenEvent}

  setup do
    Repo.delete_all(TokenEvent)
    Repo.delete_all(Token)
    start_supervised!(ExpirationScheduler)
    start_supervised!(TokenManager)
    :ok
  end

  describe "allocate/1" do
    test "allocates available token" do
      token = insert_token()
      user_id = Ecto.UUID.generate()

      assert {:ok, token_id, ^user_id} = TokenManager.allocate(user_id)
      assert token_id == token.id

      db_token = Repo.get!(Token, token_id)
      assert db_token.status == "active"
      assert db_token.active_user_id == user_id
    end

    test "reuses oldest active token when 100 are active" do
      base = DateTime.utc_now()

      Enum.each(1..100, fn idx ->
        ts = DateTime.add(base, idx, :second)

        insert_token(%{
          inserted_at: ts,
          updated_at: ts,
          last_activated_at: ts
        })

        user = Ecto.UUID.generate()
        assert {:ok, token_id, ^user} = TokenManager.allocate(user)
        assert token_id == TokensRepo.get_token!(token_id).id
        Process.sleep(1)
      end)

      new_user = Ecto.UUID.generate()
      state = :sys.get_state(TokenManager)
      {oldest_id, _} = Enum.min_by(state.active, fn {_id, last} -> last end)

      assert {:ok, reused_id, ^new_user} = TokenManager.allocate(new_user)
      assert reused_id == oldest_id

      db_token = Repo.get!(Token, reused_id)
      assert db_token.active_user_id == new_user
    end
  end

  describe "release/1" do
    test "returns error when token not active" do
      token = insert_token()
      assert {:error, :token_not_active} = TokenManager.release(token.id)
    end
  end

  defp insert_token(attrs \\ %{}) do
    defaults = %{
      status: "available",
      last_activated_at: nil,
      active_user_id: nil
    }

    timestamps = Map.take(attrs, [:inserted_at, :updated_at])
    token_attrs = Map.merge(defaults, Map.drop(attrs, [:inserted_at, :updated_at]))

    %Token{}
    |> struct(timestamps)
    |> Token.changeset(token_attrs)
    |> Repo.insert!()
  end
end
