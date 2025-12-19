defmodule TokenManagementService.Tokens.Queries.TokenEventQuery do
  import Ecto.Query, only: [from: 2]
  alias TokenManagementService.Tokens.Schemas.TokenEvent

  def by_token_id(token_id) do
    from e in TokenEvent, where: e.token_id == ^token_id
  end

  @spec recent_for_token(any(), any()) :: Ecto.Query.t()
  def recent_for_token(token_id, limit \\ 50) do
    from e in by_token_id(token_id),
      order_by: [desc: e.occurred_at],
      limit: ^limit
  end

  def list_by_token(token_id) do
    from e in TokenEvent,
      where: e.token_id == ^token_id,
      order_by: [desc: e.occurred_at]
  end
end
