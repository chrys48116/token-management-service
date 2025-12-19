defmodule TokenManagementService.Tokens.RepoTest do
  use TokenManagementService.DataCase, async: false

  alias TokenManagementService.Tokens.Repo, as: TokensRepo
  alias TokenManagementService.Tokens.Schemas.{Token, TokenEvent}

  describe "activate_token/4" do
    test "marks the token as active and records an activated event" do
      token = insert_token()
      user_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      assert {:ok, %{token: %Token{} = updated, event: %TokenEvent{} = event}} =
               TokensRepo.activate_token(token.id, user_id, now, %{reason: "test"})

      assert updated.status == "active"
      assert updated.active_user_id == user_id
      assert event.event == "activated"
      assert event.metadata["user_id"] == user_id
      assert event.metadata["reason"] == "test"
    end
  end

  describe "release_token/3" do
    test "marks the token available and records released event with user_id" do
      token = insert_token(%{status: "active", active_user_id: Ecto.UUID.generate()})
      now = DateTime.utc_now()

      assert {:ok, %{token: %Token{} = updated, event: %TokenEvent{} = event}} =
               TokensRepo.release_token(token.id, now, %{reason: "manual"})

      assert updated.status == "available"
      assert updated.active_user_id == nil
      assert event.event == "released"
      assert event.metadata["user_id"] == token.active_user_id
      assert event.metadata["reason"] == "manual"
    end
  end

  describe "expire_token/3" do
    test "records expired event and clears active user" do
      token = insert_token(%{status: "active", active_user_id: Ecto.UUID.generate()})
      now = DateTime.utc_now()

      assert {:ok, %{token: %Token{} = updated, event: %TokenEvent{} = event}} =
               TokensRepo.expire_token(token.id, now, %{reason: "ttl"})

      assert updated.status == "available"
      assert event.event == "expired"
      assert event.metadata["user_id"] == token.active_user_id
      assert event.metadata["reason"] == "ttl"
    end
  end

  describe "list_tokens/1" do
    test "filters by status" do
      available = insert_token(%{status: "available"})

      active =
        insert_token(%{
          status: "active",
          active_user_id: Ecto.UUID.generate(),
          last_activated_at: DateTime.utc_now()
        })

      assert Enum.map(TokensRepo.list_tokens("available"), & &1.id) == [available.id]
      assert Enum.map(TokensRepo.list_tokens("active"), & &1.id) == [active.id]

      assert Enum.sort(Enum.map(TokensRepo.list_tokens("all"), & &1.id)) ==
               Enum.sort([available.id, active.id])
    end
  end

  describe "list_events/1" do
    test "returns events ordered by occurred_at desc" do
      token = insert_token()
      user_id = Ecto.UUID.generate()
      now = DateTime.utc_now()

      {:ok, _} = TokensRepo.activate_token(token.id, user_id, now, %{})
      {:ok, _} = TokensRepo.release_token(token.id, DateTime.add(now, 1, :second), %{})

      events = TokensRepo.list_events(token.id)
      assert length(events) == 2
      assert Enum.at(events, 0).event == "released"
      assert Enum.at(events, 1).event == "activated"
    end
  end

  defp insert_token(attrs \\ %{}) do
    params =
      attrs
      |> Map.put_new(:status, "available")
      |> Map.put_new(:last_activated_at, nil)
      |> Map.put_new(:active_user_id, nil)

    %Token{}
    |> Token.changeset(params)
    |> Repo.insert!()
  end
end
