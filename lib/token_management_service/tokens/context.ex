defmodule TokenManagementService.Tokens do
  @moduledoc """
  Public interface for token domain operations.
  """

  alias TokenManagementService.TokenPool.TokenManager

  def allocate_token(user_id) when is_binary(user_id) do
    TokenManager.allocate(user_id)
  end


  def release_token(token_id) do
    TokenManager.release(token_id)
  end
end
