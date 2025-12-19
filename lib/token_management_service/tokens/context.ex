defmodule TokenManagementService.Tokens do
  @moduledoc """
  Public interface for the token domain.

  Exposes the use-cases consumed by the web layer while hiding OTP and
  persistence concerns behind a clean API.
  """

  alias TokenManagementService.TokenPool.TokenManager
  alias TokenManagementService.Tokens.Repo, as: TokensRepo
  alias TokenManagementService.Tokens.Schemas.{Token, TokenEvent}

  @type status_filter :: String.t()

  @spec allocate_token(binary()) :: any()
  @doc """
  Allocates a token for the provided `user_id`.

  Delegates to `TokenManager`, which enforces LRU eviction, schedules TTL timers
  and persists the activation event.
  """
  @spec allocate_token(String.t()) :: {:ok, String.t(), String.t()} | {:error, term()}
  def allocate_token(user_id) when is_binary(user_id) do
    TokenManager.allocate(user_id)
  end

  @spec release_token(any()) :: any()
  @doc """
  Releases a token by id, returning `:ok` or an error tuple.

  The GenServer validates whether the token is active and cancels TTL timers.
  """
  @spec release_token(String.t()) :: :ok | {:error, term()}
  def release_token(token_id) do
    TokenManager.release(token_id)
  end

  @spec list_tokens() :: {:error, :invalid_status} | {:ok, any()}
  @doc """
  Lists tokens filtered by `status`.

  Accepts `"all"`, `"available"` or `"active"`, returning `{:ok, list}`. Invalid
  filters yield `{:error, :invalid_status}`.
  """
  @spec list_tokens(status_filter()) :: {:ok, [Token.t()]} | {:error, :invalid_status}
  def list_tokens(status \\ "all") do
    {:ok, TokensRepo.list_tokens(status)}
  rescue
    ArgumentError -> {:error, :invalid_status}
  end

  @spec get_token(any()) :: any()
  @doc """
  Fetches a token struct or `nil` when it does not exist.
  """
  @spec get_token(String.t()) :: Token.t() | nil
  def get_token(token_id) do
    TokensRepo.get_token(token_id)
  end

  @spec list_events(any()) :: {:error, :not_found} | {:ok, any()}
  @doc """
  Returns the ordered stream of events for the given token.
  """
  @spec list_events(String.t()) :: {:ok, [TokenEvent.t()]} | {:error, :not_found}
  def list_events(token_id) do
    case TokensRepo.get_token(token_id) do
      nil -> {:error, :not_found}
      _ -> {:ok, TokensRepo.list_events(token_id)}
    end
  end

  @spec cleanup_active_tokens() :: any()
  @doc """
  Releases every token currently tracked as active by the TokenManager.
  """
  @spec cleanup_active_tokens() :: {:ok, non_neg_integer()} | {:error, term()}
  def cleanup_active_tokens do
    TokenManager.cleanup_active_tokens()
  end
end
