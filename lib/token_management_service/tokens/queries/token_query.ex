defmodule TokenManagementService.Tokens.Queries.TokenQuery do
  import Ecto.Query, only: [from: 2]
  alias TokenManagementService.Tokens.Schemas.Token

  def by_id(id) do
    from t in Token, where: t.id == ^id
  end

  def active do
    from t in Token, where: t.status == "active"
  end

  def available do
    from t in Token, where: t.status == "available"
  end

  def pick_available_one do
    from t in available(),
      order_by: [asc: t.inserted_at],
      limit: 1
  end

  def oldest_active do
    from t in active(),
      where: not is_nil(t.last_activated_at),
      order_by: [asc: t.last_activated_at],
      limit: 1
  end

  def count_active do
    from t in active(), select: count(t.id)
  end

  def list_all do
    from t in Token, order_by: [asc: t.inserted_at]
  end

  def list_available do
    from t in Token, where: t.status == "available", order_by: [asc: t.inserted_at]
  end

  def list_active do
    from t in active(), order_by: [asc: t.last_activated_at]
  end
end
