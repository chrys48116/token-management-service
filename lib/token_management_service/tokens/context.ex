defmodule TokenManagementService.Tokens do
  @moduledoc """
  Public interface for token domain operations.
  """

  alias TokenManagementService.TokenPool.TokenManager
  alias TokenManagementService.Tokens.Repo, as: TokensRepo

  def allocate_token(user_id) when is_binary(user_id) do
    TokenManager.allocate(user_id)
  end

  def release_token(token_id) do
    TokenManager.release(token_id)
  end

  def list_tokens(status \\ "all") do
    {:ok, TokensRepo.list_tokens(status)}
  rescue
    ArgumentError -> {:error, :invalid_status}
  end

  def get_token(token_id) do
    TokensRepo.get_token(token_id)
  end

  def list_events(token_id) do
    case TokensRepo.get_token(token_id) do
      nil -> {:error, :not_found}
      _ -> {:ok, TokensRepo.list_events(token_id)}
    end
  end

  def cleanup_active_tokens do
    TokenManager.cleanup_active_tokens()
  end
end
