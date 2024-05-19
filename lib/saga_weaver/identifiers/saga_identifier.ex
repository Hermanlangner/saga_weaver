defmodule SagaWeaver.Identifiers.SagaIdentifier do
  @moduledoc """
  This module is responsible for generating unique identifiers for sagas.
  """
  alias SagaWeaver.Identifiers.DefaultIdentifier

  @callback unique_saga_id(any(), any(), any()) :: {:ok, any()} | {:error, any()}

  def unique_saga_id(message, entity_name, unique_saga_id_mapping) do
    impl().unique_saga_id(message, entity_name, unique_saga_id_mapping)
  end

  defp impl, do: DefaultIdentifier
end
