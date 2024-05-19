defmodule ExSaga.Behaviours.EntityIdentifier do
  @callback identity_key(any(), any(), any()) :: {:ok, any()} | {:error, any()}
end
