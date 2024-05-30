defmodule SagaWeaver.Identifiers.SagaIdentifier do
  @moduledoc """
  This module is responsible for generating unique identifiers for sagas.
  """
  alias SagaWeaver.Identifiers.DefaultIdentifier

  @callback unique_saga_id(map(), atom(), map()) :: String.t()
  @callback get_mapped_saga_ids(map(), map()) :: map()

  @spec unique_saga_id(map(), atom(), map()) :: String.t()
  def unique_saga_id(message, entity_name, unique_saga_id_mapping) do
    impl().unique_saga_id(message, entity_name, unique_saga_id_mapping)
  end

  @spec get_mapped_saga_ids(map(), map()) :: map()
  def get_mapped_saga_ids(message, unique_saga_id_mapping) do
    impl().get_mapped_saga_ids(message, unique_saga_id_mapping)
  end

  defp impl, do: DefaultIdentifier
end
