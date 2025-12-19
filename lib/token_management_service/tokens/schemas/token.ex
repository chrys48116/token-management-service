defmodule TokenManagementService.Tokens.Schemas.Token do
  @moduledoc """
  Ecto schema representing the current state of a token in the pool.

  Only two statuses are allowed: `\"available\"` and `\"active\"`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(available active)

  schema "tokens" do
    field :status, :string
    field :last_activated_at, :utc_datetime_usec
    field :active_user_id, Ecto.UUID

    timestamps(type: :utc_datetime_usec)
  end

  @typedoc "Persistent representation of a token."
  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:status, :last_activated_at, :active_user_id])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
  end
end
