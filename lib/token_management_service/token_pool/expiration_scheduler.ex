defmodule TokenManagementService.TokenPool.ExpirationScheduler do
  @moduledoc """
  Lightweight GenServer that manages per-token TTL timers.

  Each schedule request stores the timer reference and notifies `TokenManager`
  when the two-minute window expires.
  """

  use GenServer

  alias TokenManagementService.TokenPool.TokenManager

  @type token_id :: String.t()
  @type timer_ref :: reference()

  # Public API

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  @doc "Starts the scheduler under supervision."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  @spec schedule(token_id(), non_neg_integer()) :: :ok
  @doc """
  Schedules an expiration message for `token_id` after `ms` milliseconds.
  """
  def schedule(token_id, ms) when is_binary(token_id) and is_integer(ms) and ms >= 0 do
    GenServer.cast(__MODULE__, {:schedule, token_id, ms})
  end

  @spec cancel(token_id()) :: :ok
  @doc """
  Cancels any pending expiration for `token_id`.
  """
  def cancel(token_id) when is_binary(token_id) do
    GenServer.cast(__MODULE__, {:cancel, token_id})
  end

  # GenServer

  @impl true
  def init(_opts), do: {:ok, %{timers: %{}}}

  @impl true
  def handle_cast({:schedule, token_id, ms}, state) do
    state = cancel_timer_if_exists(state, token_id)

    ref = Process.send_after(self(), {:fire, token_id}, ms)
    {:noreply, put_in(state.timers[token_id], ref)}
  end

  @impl true
  def handle_cast({:cancel, token_id}, state) do
    {:noreply, cancel_timer_if_exists(state, token_id)}
  end

  @impl true
  def handle_info({:fire, token_id}, state) do
    state = update_in(state.timers, &Map.delete(&1, token_id))

    send(TokenManager, {:expire_token, token_id})

    {:noreply, state}
  end

  defp cancel_timer_if_exists(state, token_id) do
    case Map.get(state.timers, token_id) do
      nil ->
        state

      ref when is_reference(ref) ->
        _ = Process.cancel_timer(ref)
        update_in(state.timers, &Map.delete(&1, token_id))
    end
  end
end
