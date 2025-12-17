defmodule TokenManagementService.Repo.Migrations.CreateTokenEvents do
  use Ecto.Migration

  def change do
    create table(:token_events, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :token_id, references(:tokens, type: :uuid, on_delete: :delete_all),
        null: false

      add :event, :string, null: false
      add :occurred_at, :utc_datetime_usec, null: false
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:token_events, [:token_id])
    create index(:token_events, [:event])
    create index(:token_events, [:occurred_at])
  end
end
