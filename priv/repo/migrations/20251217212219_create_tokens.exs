defmodule TokenManagementService.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :status, :string, null: false
      add :last_activated_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:tokens, [:status])
    create index(:tokens, [:last_activated_at])
  end
end
