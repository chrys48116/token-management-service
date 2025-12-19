defmodule TokenManagementServiceWeb.TokenController do
  @moduledoc """
  JSON controller exposing the token management API.

  Each action delegates to the `TokenManagementService.Tokens` context and
  translates domain tuples into HTTP responses.
  """
  use TokenManagementServiceWeb, :controller

  alias TokenManagementService.Tokens

  # POST /api/tokens/allocate
  def allocate(conn, _params) do
    user_id = Ecto.UUID.generate()

    case Tokens.allocate_token(user_id) do
      {:ok, token_id, user_id} ->
        json(conn, %{token_id: token_id, user_id: user_id})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  # POST /api/tokens/:id/release
  def release(conn, %{"id" => token_id}) do
    case Tokens.release_token(token_id) do
      :ok ->
        json(conn, %{ok: true})

      {:error, :token_not_active} ->
        conn |> put_status(:not_found) |> json(%{error: "token_not_active"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  # GET /api/tokens?status=available|active|all
  def index(conn, params) do
    status = Map.get(params, "status", "all")

    case Tokens.list_tokens(status) do
      {:ok, tokens} ->
        json(conn, %{tokens: Enum.map(tokens, &render_token/1)})

      {:error, :invalid_status} ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_status"})
    end
  end

  # GET /api/tokens/:id
  def show(conn, %{"id" => token_id}) do
    case Tokens.get_token(token_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      token ->
        json(conn, render_token(token))
    end
  end

  # GET /api/tokens/:id/events
  def events(conn, %{"id" => token_id}) do
    case Tokens.list_events(token_id) do
      {:ok, events} ->
        json(conn, %{token_id: token_id, events: Enum.map(events, &render_event/1)})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end

  # POST /api/tokens/cleanup
  def cleanup(conn, _params) do
    case Tokens.cleanup_active_tokens() do
      {:ok, released} ->
        json(conn, %{released: released})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: inspect(reason)})
    end
  end

  defp render_token(token) do
    %{
      id: token.id,
      status: token.status,
      last_activated_at: token.last_activated_at,
      active_user_id: token.active_user_id
    }
  end

  defp render_event(event) do
    %{
      id: event.id,
      token_id: event.token_id,
      event: event.event,
      occurred_at: event.occurred_at,
      metadata: event.metadata
    }
  end
end
