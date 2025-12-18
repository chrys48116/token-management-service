defmodule TokenManagementService.TokenPool.TokenManager do
  use GenServer

  alias TokenManagementService.Tokens.Repo, as: TokensRepo

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  def allocate do
    GenServer.call(__MODULE__, :allocate)
  end

  def release(token_id) do
    GenServer.call(__MODULE__, {:release, token_id})
  end

  @impl true
  def init(_opts) do
    _active_tokens = TokensRepo.list_active_tokens()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:allocate, _from, state) do
    now = DateTime.utc_now()

    case TokensRepo.get_available_token() do
      nil ->
        case TokensRepo.get_oldest_active_token() do
          nil ->
            {:reply, {:error, :no_tokens_found}, state}

          oldest ->
            _ = TokensRepo.release_token(oldest.id, now, %{reason: "lru_eviction"})
            case TokensRepo.activate_token(oldest.id, now, %{reason: "allocated_after_eviction"}) do
              {:ok, _} -> {:reply, {:ok, oldest.id}, state}
              {:error, _step, reason, _changes} -> {:reply, {:error, reason}, state}
            end
        end

      token ->
        case TokensRepo.activate_token(token.id, now, %{reason: "allocated"}) do
          {:ok, _} -> {:reply, {:ok, token.id}, state}
          {:error, _step, reason, _changes} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:release, token_id}, _from, state) do
    now = DateTime.utc_now()

    case TokensRepo.release_token(token_id, now, %{reason: "released_by_client"}) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, _step, reason, _changes} -> {:reply, {:error, reason}, state}
    end
  end
end
