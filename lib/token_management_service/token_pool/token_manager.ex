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
    active_tokens =
      TokensRepo.list_active_tokens()
      |> Enum.reduce(%{}, fn token, acc ->
        Map.put(acc, token.id, token.last_activated_at)
      end)

    {:ok, %{active: active_tokens}}
  end

  @impl true
  def handle_call(:allocate, _from, state) do
    now = DateTime.utc_now()

    if map_size(state.active) < 100 do
      case TokensRepo.get_available_token() do
        nil ->
          {:reply, {:error, :no_available_tokens}, state}

        token ->
          case TokensRepo.activate_token(token.id, now, %{reason: "allocated"}) do
            {:ok, _} ->
              new_state =
                put_in(state.active[token.id], now)

              {:reply, {:ok, token.id}, new_state}

            {:error, _step, reason, _} ->
              {:reply, {:error, reason}, state}
          end
      end
    else
      # LRU eviction
      {lru_token_id, _} =
        Enum.min_by(state.active, fn {_id, last_used} -> last_used end)

      _ = TokensRepo.release_token(lru_token_id, now, %{reason: "lru_eviction"})

      case TokensRepo.activate_token(lru_token_id, now, %{reason: "allocated_after_eviction"}) do
        {:ok, _} ->
          new_state =
            state
            |> put_in([:active, lru_token_id], now)

          {:reply, {:ok, lru_token_id}, new_state}

        {:error, _step, reason, _} ->
          {:reply, {:error, reason}, state}
      end
    end
  end
  @impl true
  def handle_call({:release, token_id}, _from, state) do
    now = DateTime.utc_now()

    case Map.has_key?(state.active, token_id) do
      false ->
        {:reply, {:error, :token_not_active}, state}

      true ->
        case TokensRepo.release_token(token_id, now, %{reason: "released_by_client"}) do
          {:ok, _} ->
            new_state = update_in(state.active, &Map.delete(&1, token_id))
            {:reply, :ok, new_state}

          {:error, _step, reason, _} ->
            {:reply, {:error, reason}, state}
        end
    end
  end
end
