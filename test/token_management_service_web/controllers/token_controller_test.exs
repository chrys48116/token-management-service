defmodule TokenManagementServiceWeb.TokenControllerTest do
  use TokenManagementServiceWeb.ConnCase, async: false

  @moduletag :token_pool

  alias TokenManagementService.Repo
  alias TokenManagementService.TokenPool.TokenManager
  alias TokenManagementService.Tokens.Repo, as: TokensRepo
  alias TokenManagementService.Tokens.Schemas.{Token, TokenEvent}

  describe "POST /api/tokens/allocate" do
    test "activates the oldest available token", %{conn: conn} do
      token = insert_token()

      conn = post(conn, ~p"/api/tokens/allocate")

      assert %{"token_id" => token_id, "user_id" => user_id} = json_response(conn, 200)
      assert token_id == token.id

      db_token = Repo.get!(Token, token_id)
      assert db_token.status == "active"
      assert db_token.active_user_id == user_id
    end

    test "returns error when pool has no available tokens", %{conn: conn} do
      conn = post(conn, ~p"/api/tokens/allocate")

      assert %{"error" => "no_available_tokens"} = json_response(conn, 422)
    end

    @tag :lru
    test "evicts the oldest active token when 100 are in use", %{conn: conn} do
      Repo.delete_all(TokenEvent)
      Repo.delete_all(Token)
      restart_token_pool()

      base = DateTime.utc_now()

      Enum.each(1..100, fn idx ->
        ts = DateTime.add(base, idx, :second)

        insert_token(%{
          inserted_at: ts,
          updated_at: ts,
          last_activated_at: ts
        })
      end)

      conn =
        Enum.reduce(1..100, conn, fn _, conn ->
          conn = post(conn, ~p"/api/tokens/allocate")
          _ = json_response(conn, 200)
          Process.sleep(1)
          recycle(conn)
        end)

      state = :sys.get_state(TokenManager)
      {expected_id, _} = Enum.min_by(state.active, fn {_id, last_used} -> last_used end)

      conn = post(conn, ~p"/api/tokens/allocate")
      assert %{"token_id" => reused_id, "user_id" => new_user} = json_response(conn, 200)
      assert reused_id == expected_id

      token = Repo.get!(Token, reused_id)
      assert token.active_user_id == new_user
    end
  end

  describe "POST /api/tokens/:id/release" do
    test "releases an active token", %{conn: conn} do
      insert_token()

      conn = post(conn, ~p"/api/tokens/allocate")
      assert %{"token_id" => token_id} = json_response(conn, 200)

      conn = conn |> recycle() |> post(~p"/api/tokens/#{token_id}/release")

      assert %{"ok" => true} = json_response(conn, 200)
      assert Repo.get!(Token, token_id).status == "available"
    end

    test "returns not_found when token is not active", %{conn: conn} do
      token = insert_token()

      conn = post(conn, ~p"/api/tokens/#{token.id}/release")

      assert %{"error" => "token_not_active"} = json_response(conn, 404)
    end
  end

  describe "GET /api/tokens" do
    test "lists tokens filtered by status", %{conn: conn} do
      available = insert_token(%{status: "available"})

      active =
        insert_token(%{
          status: "active",
          last_activated_at: DateTime.utc_now(),
          active_user_id: Ecto.UUID.generate()
        })

      conn = get(conn, ~p"/api/tokens")
      ids = conn |> json_response(200) |> Map.fetch!("tokens") |> Enum.map(& &1["id"])
      assert Enum.sort(ids) == Enum.sort([available.id, active.id])

      conn = conn |> recycle() |> get(~p"/api/tokens?status=available")
      available_id = available.id
      assert [%{"id" => ^available_id}] = json_response(conn, 200)["tokens"]

      conn = conn |> recycle() |> get(~p"/api/tokens?status=active")
      active_id = active.id
      assert [%{"id" => ^active_id}] = json_response(conn, 200)["tokens"]
    end

    test "rejects invalid status", %{conn: conn} do
      conn = get(conn, ~p"/api/tokens?status=invalid")
      assert %{"error" => "invalid_status"} = json_response(conn, 400)
    end
  end

  describe "GET /api/tokens/:id" do
    test "returns token details", %{conn: conn} do
      token =
        insert_token(%{
          status: "active",
          last_activated_at: DateTime.utc_now(),
          active_user_id: Ecto.UUID.generate()
        })

      conn = get(conn, ~p"/api/tokens/#{token.id}")

      token_id = token.id
      active_user_id = token.active_user_id

      assert %{
               "id" => ^token_id,
               "status" => "active",
               "active_user_id" => ^active_user_id
             } = json_response(conn, 200)
    end

    test "returns not_found for missing token", %{conn: conn} do
      conn = get(conn, ~p"/api/tokens/#{Ecto.UUID.generate()}")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end

  describe "GET /api/tokens/:id/events" do
    test "lists events for a token", %{conn: conn} do
      token = insert_token()
      now = DateTime.utc_now()
      user_id = Ecto.UUID.generate()

      assert {:ok, _} = TokensRepo.activate_token(token.id, user_id, now, %{reason: "test"})

      assert {:ok, _} =
               TokensRepo.release_token(token.id, DateTime.add(now, 1, :second), %{reason: "test"})

      conn = get(conn, ~p"/api/tokens/#{token.id}/events")
      events = json_response(conn, 200)["events"]

      assert length(events) == 2
      assert Enum.all?(events, fn event -> event["token_id"] == token.id end)
    end

    test "returns not_found when token does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/tokens/#{Ecto.UUID.generate()}/events")
      assert %{"error" => "not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/tokens/cleanup" do
    test "releases all active tokens", %{conn: conn} do
      insert_token()
      insert_token()

      conn = post(conn, ~p"/api/tokens/allocate")
      assert %{"token_id" => first_id} = json_response(conn, 200)

      conn = conn |> recycle() |> post(~p"/api/tokens/allocate")
      assert %{"token_id" => second_id} = json_response(conn, 200)

      conn = conn |> recycle() |> post(~p"/api/tokens/cleanup")
      assert %{"released" => 2} = json_response(conn, 200)

      assert Repo.get!(Token, first_id).status == "available"
      assert Repo.get!(Token, second_id).status == "available"
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

  defp restart_token_pool do
    stop_supervised(TokenManagementService.TokenPool.TokenManager)
    stop_supervised(TokenManagementService.TokenPool.ExpirationScheduler)
    start_supervised!(TokenManagementService.TokenPool.ExpirationScheduler)
    start_supervised!(TokenManagementService.TokenPool.TokenManager)
  end
end
