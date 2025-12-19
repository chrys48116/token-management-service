defmodule TokenManagementService.TokenPool.TokenManager do
  @moduledoc """
  GenServer responsible for enforcing the token invariants.

  It keeps the in-memory view of active tokens, applies the 100 token ceiling,
  performs LRU eviction, schedules TTL expirations and delegates persistence to
  `TokenManagementService.Tokens.Repo`.
  """

  use GenServer

  alias TokenManagementService.Tokens.Repo, as: TokensRepo
  alias TokenManagementService.TokenPool.ExpirationScheduler

  @ttl_ms 2 * 60 * 1000
  @type token_id :: String.t()
  @type user_id :: String.t()

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  @doc """
  Starts the TokenManager under a supervisor.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  @spec allocate(user_id()) :: {:ok, token_id(), user_id()} | {:error, term()}
  @doc """
  Allocates a token for `user_id`, enforcing LRU and TTL scheduling.
  """
  def allocate(user_id) when is_binary(user_id) do
    GenServer.call(__MODULE__, {:allocate, user_id})
  end

  @spec release(token_id()) :: :ok | {:error, term()}
  @doc """
  Releases a token by id, cancelling timers and persisting the event.
  """
  def release(token_id) do
    GenServer.call(__MODULE__, {:release, token_id})
  end

  @spec cleanup_active_tokens() :: {:ok, non_neg_integer()} | {:error, term()}
  @doc """
  Releases every currently active token and returns how many were cleaned up.
  """
  def cleanup_active_tokens do
    GenServer.call(__MODULE__, :cleanup_active_tokens)
  end

  @impl true
  @spec init(term()) :: {:ok, %{active: %{token_id() => DateTime.t()}}}
  def init(_opts) do
    now = DateTime.utc_now()

    active_tokens =
      TokensRepo.list_active_tokens()
      |> Enum.reduce(%{}, fn token, acc ->
        Map.put(acc, token.id, token.last_activated_at)
      end)

    {active_after_reconcile, _scheduled_count} =
      Enum.reduce(active_tokens, {%{}, 0}, fn {token_id, last_activated_at}, {acc, scheduled} ->
        elapsed_ms = DateTime.diff(now, last_activated_at, :millisecond)
        remaining_ms = @ttl_ms - elapsed_ms

        cond do
          remaining_ms <= 0 ->
            _ = expire_token_if_active(token_id, now)
            {acc, scheduled}

          true ->
            ExpirationScheduler.schedule(token_id, remaining_ms)
            {Map.put(acc, token_id, last_activated_at), scheduled + 1}
        end
      end)

    {:ok, %{active: active_after_reconcile}}
  end

  @impl true
  def handle_call({:allocate, user_id}, _from, state) do
    now = DateTime.utc_now()

    if map_size(state.active) < 100 do
      case TokensRepo.get_available_token() do
        nil ->
          {:reply, {:error, :no_available_tokens}, state}

        token ->
          case TokensRepo.activate_token(token.id, user_id, now, %{reason: "allocated"}) do
            {:ok, _} ->
              new_state = put_in(state.active[token.id], now)

              ExpirationScheduler.schedule(token.id, @ttl_ms)

              {:reply, {:ok, token.id, user_id}, new_state}

            {:error, _step, reason, _} ->
              {:reply, {:error, reason}, state}
          end
      end
    else
      {lru_token_id, _} =
        Enum.min_by(state.active, fn {_id, last_used} -> last_used end)

      _ = TokensRepo.release_token(lru_token_id, now, %{reason: "lru_eviction"})
      ExpirationScheduler.cancel(lru_token_id)

      case TokensRepo.activate_token(lru_token_id, user_id, now, %{
             reason: "allocated_after_eviction"
           }) do
        {:ok, _} ->
          new_state =
            state
            |> put_in([:active, lru_token_id], now)

          ExpirationScheduler.schedule(lru_token_id, @ttl_ms)

          {:reply, {:ok, lru_token_id, user_id}, new_state}

        {:error, _step, reason, _} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call(:cleanup_active_tokens, _from, state) do
    now = DateTime.utc_now()

    {released_ids, maybe_error} =
      Enum.reduce(state.active, {[], nil}, fn {token_id, _}, {released, error_reason} ->
        case TokensRepo.release_token(token_id, now, %{reason: "cleanup"}) do
          {:ok, _} ->
            ExpirationScheduler.cancel(token_id)
            {[token_id | released], error_reason}

          {:error, _step, reason, _changes} ->
            {released, error_reason || reason}
        end
      end)

    new_active = Map.drop(state.active, released_ids)

    reply =
      case maybe_error do
        nil -> {:ok, length(released_ids)}
        reason -> {:error, reason}
      end

    {:reply, reply, %{state | active: new_active}}
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
            ExpirationScheduler.cancel(token_id)

            new_state = update_in(state.active, &Map.delete(&1, token_id))

            {:reply, :ok, new_state}

          {:error, _step, reason, _} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_info({:expire_token, token_id}, state) do
    now = DateTime.utc_now()

    if Map.has_key?(state.active, token_id) do
      case TokensRepo.expire_token(token_id, now, %{reason: "ttl_expired"}) do
        {:ok, _} ->
          new_state = update_in(state.active, &Map.delete(&1, token_id))
          {:noreply, new_state}

        {:error, _step, _reason, _changes} ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  defp expire_token_if_active(token_id, now) do
    TokensRepo.expire_token(token_id, now, %{reason: "ttl_boot_reconcile"})
  end
end
