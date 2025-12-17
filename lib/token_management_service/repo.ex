defmodule TokenManagementService.Repo do
  use Ecto.Repo,
    otp_app: :token_management_service,
    adapter: Ecto.Adapters.Postgres
end
