defmodule TokenManagementService.Tokens.TokenManager do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    initial_state = %{
      available_tokens: [],
      active_tokens: %{}
    }

    {:ok, initial_state}
  end
end
