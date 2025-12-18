defmodule TokenManagementService.Tokens.Repo do
  alias Ecto.Multi
  alias TokenManagementService.Repo

  alias TokenManagementService.Tokens.Queries.TokenQuery
  alias TokenManagementService.Tokens.Schemas.{Token, TokenEvent}

  def count_active do
    Repo.one(TokenQuery.count_active())
  end

  def get_available_token do
    Repo.one(TokenQuery.pick_available_one())
  end

  def get_oldest_active_token do
    Repo.one(TokenQuery.oldest_active())
  end

  def list_active_tokens do
    Repo.all(TokenQuery.list_active())
  end

  def get_token!(id) do
    Repo.one!(TokenQuery.by_id(id))
  end

  def activate_token(%Token{id: token_id} = _token, occurred_at, metadata \\ %{}) do
    activate_token(token_id, occurred_at, metadata)
  end

  def activate_token(token_id, occurred_at, metadata) do
    Multi.new()
    |> Multi.update(:token, token_active_changeset(token_id, occurred_at))
    |> Multi.insert(:event, build_event_changeset(token_id, "activated", occurred_at, metadata))
    |> Repo.transaction()
  end

  def release_token(%Token{id: token_id} = _token, occurred_at, metadata \\ %{}) do
    release_token(token_id, occurred_at, metadata)
  end

  def release_token(token_id, occurred_at, metadata) do
    Multi.new()
    |> Multi.update(:token, token_available_changeset(token_id))
    |> Multi.insert(:event, build_event_changeset(token_id, "released", occurred_at, metadata))
    |> Repo.transaction()
  end

  def expire_token(%Token{id: token_id} = _token, occurred_at, metadata \\ %{}) do
    expire_token(token_id, occurred_at, metadata)
  end

  def expire_token(token_id, occurred_at, metadata) do
    Multi.new()
    |> Multi.update(:token, token_available_changeset(token_id))
    |> Multi.insert(:event, build_event_changeset(token_id, "expired", occurred_at, metadata))
    |> Repo.transaction()
  end

  defp token_active_changeset(token_id, occurred_at) do
    token = get_token!(token_id)

    Token.changeset(token, %{
      status: "active",
      last_activated_at: occurred_at
    })
  end

  defp token_available_changeset(token_id) do
    token = get_token!(token_id)

    Token.changeset(token, %{
      status: "available"
    })
  end

  defp build_event_changeset(token_id, event, occurred_at, metadata) do
    TokenEvent.changeset(%TokenEvent{}, %{
      token_id: token_id,
      event: event,
      occurred_at: occurred_at,
      metadata: metadata
    })
  end
end
