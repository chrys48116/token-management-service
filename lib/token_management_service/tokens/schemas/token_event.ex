defmodule TokenManagementService.Tokens.Schemas.TokenEvent do
  @moduledoc """
  Ecto schema for the audit trail of token usage (`token_events` table).

  Events are limited to `activated`, `released` and `expired`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TokenManagementService.Tokens.Schemas.Token

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @events ~w(activated released expired)

  schema "token_events" do
    field :event, :string
    field :occurred_at, :utc_datetime_usec
    field :metadata, :map

    belongs_to :token, Token

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(
          {map(),
           %{
             optional(atom()) =>
               atom()
               | {:array | :assoc | :embed | :in | :map | :parameterized | :supertype | :try,
                  any()}
           }}
          | %{
              :__struct__ => atom() | %{:__changeset__ => map(), optional(any()) => any()},
              optional(atom()) => any()
            },
          :invalid | %{optional(:__struct__) => none(), optional(atom() | binary()) => any()}
        ) :: Ecto.Changeset.t()
  @typedoc "Audit event snapshot for a token."
  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(token_event, attrs) do
    token_event
    |> cast(attrs, [:token_id, :event, :occurred_at, :metadata])
    |> validate_required([:token_id, :event, :occurred_at])
    |> validate_inclusion(:event, @events)
  end
end
