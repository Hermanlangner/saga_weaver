defmodule SagaWeaver.Compatibility do
  @moduledoc """
  Helpers for migrating SagaWeaver 0.2 saga definitions and persisted keys.

  Existing saga identifiers are durable data. `v1_key/2` derives the exact
  key used by the 0.2 identity algorithm so a new `route/1` callback can
  continue existing instances without rewriting storage.
  """

  alias SagaWeaver.Identifiers.DefaultIdentifier

  @doc """
  Derives a SagaWeaver 0.2 identifier for a saga and message.

  Returns a descriptive error when the message has no legacy identity mapping
  instead of invoking a missing function.
  """
  @spec v1_key(module(), struct()) :: {:ok, String.t()} | {:error, term()}
  def v1_key(saga, %{__struct__: message_module} = message) when is_atom(saga) do
    with true <- function_exported?(saga, :identity_key_mapping, 0),
         true <- function_exported?(saga, :entity_name, 0),
         mappings when is_map(mappings) <- saga.identity_key_mapping(),
         {:ok, extractor} <- Map.fetch(mappings, message_module),
         {:ok, identifiers} <- extract_identifiers(extractor, message) do
      {:ok, build_v1_key(saga.entity_name(), identifiers)}
    else
      false -> {:error, {:invalid_legacy_saga, saga}}
      :error -> {:error, {:missing_identity_mapping, message_module}}
      value -> {:error, {:invalid_identity_mapping, value}}
    end
  end

  def v1_key(_saga, message), do: {:error, {:invalid_message, message}}

  defp extract_identifiers(extractor, message) when is_function(extractor, 1) do
    case extractor.(message) do
      identifiers when is_map(identifiers) -> {:ok, identifiers}
      value -> {:error, {:invalid_identity, value}}
    end
  rescue
    error -> {:error, {:identity_error, error}}
  end

  defp extract_identifiers(extractor, _message), do: {:error, {:invalid_extractor, extractor}}

  defp build_v1_key(entity_name, identifiers) do
    message_module = __MODULE__.V1Message
    message = struct(message_module, identifiers: identifiers)
    mapping = %{message_module => & &1.identifiers}
    DefaultIdentifier.unique_saga_id(message, entity_name, mapping)
  end

  defmodule V1Message do
    @moduledoc false
    defstruct [:identifiers]
  end
end
