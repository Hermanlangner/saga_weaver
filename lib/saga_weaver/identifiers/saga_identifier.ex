defmodule SagaWeaver.Behaviours.SagaIdentifier do
  @callback unique_saga_id(any(), any(), any()) :: {:ok, any()} | {:error, any()}
end

defmodule SagaWeaver.Identifiers.SagaIdentifier do
  @moduledoc """
  This module is responsible for generating unique identifiers for sagas.
  """

  def unique_saga_id(message, entity_name, unique_saga_id_mapping) do
    entity_name
    |> to_string()
    |> Kernel.<>(":")
    |> Kernel.<>(get_unique_saga_id(message, unique_saga_id_mapping))
  end

  defp get_unique_saga_id(message, unique_saga_id_mapping) do
    unique_saga_ids = unique_saga_id_mapping[message.__struct__].(message)

    unique_saga_ids
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
