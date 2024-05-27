defmodule SagaWeaver.Identifiers.DefaultIdentifier do
  @moduledoc """
  Default identifier module for SagaWeaver.
  """

  @behaviour SagaWeaver.Identifiers.SagaIdentifier

  alias SagaWeaver.Identifiers.SagaIdentifier

  @impl SagaIdentifier
  def unique_saga_id(message, entity_name, unique_saga_id_mapping) do
    hashed_saga_ids =
      get_mapped_saga_ids(message, unique_saga_id_mapping)
      |> ids_to_sha()

    unique_id =
      entity_name
      |> to_string()
      |> Kernel.<>(":")
      |> Kernel.<>(hashed_saga_ids)

    unique_id
  end

  def get_mapped_saga_ids(message, unique_saga_id_mapping) do
    unique_saga_id_mapping[message.__struct__].(message)
  end

  def ids_to_sha(saga_ids) do
    saga_ids
    |> Enum.reduce("", fn {key, value}, acc ->
      acc <> "#{to_string(key)}:#{to_string(value)},"
    end)
    |> md5_hash()
  end

  defp md5_hash(input_string) do
    :crypto.hash(:sha256, input_string)
    |> Base.encode16(case: :lower)
  end
end
