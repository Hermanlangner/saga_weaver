defmodule SagaWeaver.Identifiers.SagaIdentifier do
  @moduledoc """
  This module is responsible for generating unique identifiers for sagas.
  """
  alias SagaWeaver.Identifiers.DefaultIdentifier

  @doc "Builds the persisted identifier used by the legacy saga API."
  @callback unique_saga_id(map(), atom(), map()) :: String.t()

  @doc "Extracts identity values through a legacy message mapping."
  @callback get_mapped_saga_ids(map(), map()) :: map()

  @doc "Builds the persisted identifier used by the legacy saga API."
  @spec unique_saga_id(map(), atom(), map()) :: String.t()
  def unique_saga_id(message, entity_name, unique_saga_id_mapping) do
    impl().unique_saga_id(message, entity_name, unique_saga_id_mapping)
  end

  @doc "Extracts identity values through a legacy message mapping."
  @spec get_mapped_saga_ids(map(), map()) :: map()
  def get_mapped_saga_ids(message, unique_saga_id_mapping) do
    impl().get_mapped_saga_ids(message, unique_saga_id_mapping)
  end

  defp impl, do: DefaultIdentifier
end
