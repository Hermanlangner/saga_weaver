defmodule ExSaga.Identifier do
  @moduledoc """
  This module is responsible for generating unique identifiers for sagas.
  """

  def instance_name(event, entity_name, identity_key_mapping) do
    entity_name
    |> to_string()
    |> Kernel.<>(":")
    |> Kernel.<>(get_identity_key(event, identity_key_mapping))
  end

  def get_identity_key(event, identity_key_mapping) do
    identity_keys = identity_key_mapping[event.__struct__].(event)

    identity_keys
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
