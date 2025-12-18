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

  def activate_token(token_or_id, user_id, occurred_at, metadata \\ %{})
  def release_token(token_or_id, occurred_at, metadata \\ %{})
  def expire_token(token_or_id, occurred_at, metadata \\ %{})

  def activate_token(%Token{id: token_id}, user_id, occurred_at, metadata) do
    activate_token(token_id, user_id, occurred_at, metadata)
  end

  def activate_token(token_id, user_id, occurred_at, metadata) when is_binary(token_id) do
    metadata =
      metadata
      |> normalize_metadata()
      |> Map.put("user_id", user_id)

    Multi.new()
    |> Multi.update(:token, token_active_changeset(token_id, user_id, occurred_at))
    |> Multi.insert(:event, build_event_changeset(token_id, "activated", occurred_at, metadata))
    |> Repo.transaction()
  end

  def release_token(%Token{id: token_id}, occurred_at, metadata) do
    release_token(token_id, occurred_at, metadata)
  end

  def release_token(token_id, occurred_at, metadata) when is_binary(token_id) do
    token = get_token!(token_id)

    metadata =
      metadata
      |> normalize_metadata()
      |> maybe_put_user_id(token.active_user_id)

    Multi.new()
    |> Multi.update(:token, token_available_changeset(token_id))
    |> Multi.insert(:event, build_event_changeset(token_id, "released", occurred_at, metadata))
    |> Repo.transaction()
  end

  def expire_token(%Token{id: token_id}, occurred_at, metadata) do
    expire_token(token_id, occurred_at, metadata)
  end

  def expire_token(token_id, occurred_at, metadata) when is_binary(token_id) do
    token = get_token!(token_id)

    metadata =
      metadata
      |> normalize_metadata()
      |> maybe_put_user_id(token.active_user_id)

    Multi.new()
    |> Multi.update(:token, token_available_changeset(token_id))
    |> Multi.insert(:event, build_event_changeset(token_id, "expired", occurred_at, metadata))
    |> Repo.transaction()
  end

  defp token_active_changeset(token_id, user_id, occurred_at) do
    token = get_token!(token_id)

    Token.changeset(token, %{
      status: "active",
      last_activated_at: occurred_at,
      active_user_id: user_id
    })
  end

  defp token_available_changeset(token_id) do
    token = get_token!(token_id)

    Token.changeset(token, %{
      status: "available",
      active_user_id: nil
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

  defp normalize_metadata(nil), do: %{}

  defp normalize_metadata(metadata) when is_map(metadata) do
    Map.new(metadata, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp maybe_put_user_id(metadata, nil), do: metadata
  defp maybe_put_user_id(metadata, user_id), do: Map.put(metadata, "user_id", user_id)
end
