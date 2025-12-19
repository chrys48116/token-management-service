defmodule TokenManagementService.Tokens.Schemas.TokenEvent do
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

  def changeset(token_event, attrs) do
    token_event
    |> cast(attrs, [:token_id, :event, :occurred_at, :metadata])
    |> validate_required([:token_id, :event, :occurred_at])
    |> validate_inclusion(:event, @events)
  end
end
