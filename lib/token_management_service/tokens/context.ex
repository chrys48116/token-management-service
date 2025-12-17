defmodule TokenManagementService.Tokens do
  @moduledoc """
  Public interface for token domain operations.
  """

  alias TokenManagementService.TokenPool.TokenManager

  def allocate_token do
    TokenManager.allocate()
  end

  def release_token(token_id) do
    TokenManager.release(token_id)
  end
end
