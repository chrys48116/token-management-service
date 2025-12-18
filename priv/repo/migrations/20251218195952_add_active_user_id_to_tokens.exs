defmodule TokenManagementService.Repo.Migrations.AddActiveUserIdToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add :active_user_id, :uuid
    end

    create index(:tokens, [:active_user_id])
  end
end
