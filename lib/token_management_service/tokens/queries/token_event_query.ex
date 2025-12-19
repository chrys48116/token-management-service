defmodule TokenManagementService.Tokens.Queries.TokenEventQuery do
  @moduledoc """
  Query helpers for retrieving token event logs.

  Separate module keeps audit access consistent and testable.
  """

  import Ecto.Query, only: [from: 2]
  alias TokenManagementService.Tokens.Schemas.TokenEvent

  @spec by_token_id(Ecto.UUID.t()) :: Ecto.Query.t()
  def by_token_id(token_id) do
    from e in TokenEvent, where: e.token_id == ^token_id
  end

  @spec recent_for_token(Ecto.UUID.t(), pos_integer()) :: Ecto.Query.t()
  def recent_for_token(token_id, limit \\ 50) do
    from e in by_token_id(token_id),
      order_by: [desc: e.occurred_at],
      limit: ^limit
  end

  @spec list_by_token(Ecto.UUID.t()) :: Ecto.Query.t()
  def list_by_token(token_id) do
    from e in TokenEvent,
      where: e.token_id == ^token_id,
      order_by: [desc: e.occurred_at]
  end
end
