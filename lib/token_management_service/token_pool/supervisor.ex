defmodule TokenManagementService.TokenPool.Supervisor do
  @moduledoc """
  Supervises the token pool processes (manager + scheduler).

  Started from the main application tree whenever token pooling is enabled.
  """
  use Supervisor

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  @spec init(:ok) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(:ok) do
    children = [
      TokenManagementService.TokenPool.TokenManager,
      TokenManagementService.TokenPool.ExpirationScheduler
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
