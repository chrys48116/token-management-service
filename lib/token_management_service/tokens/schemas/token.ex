defmodule TokenManagementService.Tokens.Schemas.Token do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(available active)

  schema "tokens" do
    field :status, :string
    field :last_activated_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:status, :last_activated_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
  end
end
