defmodule TokenManagementService.Tokens.Repo do
  @moduledoc """
  Persistence adapter backing the `TokenManagementService.Tokens` context.

  Wrapping all DB access here keeps OTP processes and controllers unaware of
  Ecto, while ensuring state and audit events stay consistent.
  """
  alias Ecto.Multi
  alias TokenManagementService.Repo

  alias TokenManagementService.Tokens.Queries.{TokenEventQuery, TokenQuery}
  alias TokenManagementService.Tokens.Schemas.{Token, TokenEvent}

  @type multi_result :: {:ok, map()} | {:error, atom(), term(), map()}

  @doc "Counts tokens currently marked as active."
  @spec count_active() :: non_neg_integer()
  def count_active do
    Repo.one(TokenQuery.count_active())
  end

  @doc "Returns the next available token ordered by insertion time."
  @spec get_available_token() :: Token.t() | nil
  def get_available_token do
    Repo.one(TokenQuery.pick_available_one())
  end

  @doc "Returns the oldest active token, used for LRU eviction."
  @spec get_oldest_active_token() :: Token.t() | nil
  def get_oldest_active_token do
    Repo.one(TokenQuery.oldest_active())
  end

  @doc "Lists active tokens ordered by their last activation timestamp."
  @spec list_active_tokens() :: [Token.t()]
  def list_active_tokens do
    Repo.all(TokenQuery.list_active())
  end

  @doc "Fetches a token raising if it does not exist."
  @spec get_token!(String.t()) :: Token.t()
  def get_token!(id) do
    Repo.one!(TokenQuery.by_id(id))
  end

  @doc """
  Marks a token as `active` and persists an `activated` event.

  Accepts either a %Token{} or an id and ensures metadata always records the `user_id`.
  """
  @spec activate_token(Token.t() | String.t(), String.t(), DateTime.t(), map() | nil) ::
          multi_result()
  def activate_token(token_or_id, user_id, occurred_at, metadata \\ %{})

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

  @doc """
  Marks a token as `available` and records a `released` event.

  Automatically copies the current `active_user_id` into metadata when present.
  """
  @spec release_token(Token.t() | String.t(), DateTime.t(), map() | nil) :: multi_result()
  def release_token(token_or_id, occurred_at, metadata \\ %{})

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

  @doc """
  Marks a token as `available` due to TTL expiration and records an `expired` event.
  """
  @spec expire_token(Token.t() | String.t(), DateTime.t(), map() | nil) :: multi_result()
  def expire_token(token_or_id, occurred_at, metadata \\ %{})

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

  @doc "Fetches a token or returns nil when missing."
  @spec get_token(String.t()) :: Token.t() | nil
  def get_token(id) do
    Repo.one(TokenQuery.by_id(id))
  end

  @doc """
  Lists tokens filtered by status.

  Accepts `"all"`, `"available"` or `"active"` and raises `ArgumentError` otherwise.
  """
  @spec list_tokens(String.t()) :: [Token.t()]
  def list_tokens("all"), do: Repo.all(TokenQuery.list_all())
  def list_tokens("available"), do: Repo.all(TokenQuery.list_available())
  def list_tokens("active"), do: Repo.all(TokenQuery.list_active())
  def list_tokens(_), do: raise(ArgumentError)

  @doc "Returns the audit trail (newest first) for a token."
  @spec list_events(String.t()) :: [TokenEvent.t()]
  def list_events(token_id) do
    Repo.all(TokenEventQuery.list_by_token(token_id))
  end
end
