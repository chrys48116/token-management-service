defmodule TokenManagementService.Tokens.Queries.TokenQuery do
  @moduledoc """
  Reusable query builders for the `tokens` table.

  Keeping query definitions separate allows Repo adapters and OTP processes to
  share consistent filtering logic.
  """

  import Ecto.Query, only: [from: 2]
  alias TokenManagementService.Tokens.Schemas.Token

  @spec by_id(Ecto.UUID.t()) :: Ecto.Query.t()
  def by_id(id) do
    from t in Token, where: t.id == ^id
  end

  @spec active() :: Ecto.Query.t()
  def active do
    from t in Token, where: t.status == "active"
  end

  @spec available() :: Ecto.Query.t()
  def available do
    from t in Token, where: t.status == "available"
  end

  @spec pick_available_one() :: Ecto.Query.t()
  def pick_available_one do
    from t in available(),
      order_by: [asc: t.inserted_at],
      limit: 1
  end

  @spec oldest_active() :: Ecto.Query.t()
  def oldest_active do
    from t in active(),
      where: not is_nil(t.last_activated_at),
      order_by: [asc: t.last_activated_at],
      limit: 1
  end

  @spec count_active() :: Ecto.Query.t()
  def count_active do
    from t in active(), select: count(t.id)
  end

  @spec list_all() :: Ecto.Query.t()
  def list_all do
    from t in Token, order_by: [asc: t.inserted_at]
  end

  @spec list_available() :: Ecto.Query.t()
  def list_available do
    from t in Token, where: t.status == "available", order_by: [asc: t.inserted_at]
  end

  @spec list_active() :: Ecto.Query.t()
  def list_active do
    from t in active(), order_by: [asc: t.last_activated_at]
  end
end
