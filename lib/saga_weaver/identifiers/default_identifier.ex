defmodule SagaWeaver.Identifiers.DefaultIdentifier do
  @moduledoc """
  The `SagaWeaver.Identifiers.DefaultIdentifier` module provides a default implementation for generating unique saga identifiers within the SagaWeaver framework.

  ## Overview

  This module implements the `SagaWeaver.Identifiers.SagaIdentifier` behaviour, supplying functions to:

  - Generate a unique saga ID based on a message, entity name, and a mapping.
  - Extract and map saga IDs from messages according to specified mappings.
  - Hash the extracted identifiers to produce a consistent and unique identifier.

  ## Key Functions

  - `unique_saga_id/3`: Generates a unique saga identifier.
  - `get_mapped_saga_ids/2`: Retrieves and maps saga IDs from a message.

  ## Usage

  This module is used internally by the SagaWeaver framework to ensure that each saga instance can be uniquely identified, preventing conflicts and ensuring messages are routed to the correct saga instance.

  ## Examples

  ```elixir
  message = %MyApp.Events.OrderPlaced{order_id: 123}
  entity_name = :order_saga
  unique_saga_id_mapping = %{
    MyApp.Events.OrderPlaced => fn msg -> %{order_id: msg.order_id} end
  }

  unique_id = SagaWeaver.Identifiers.DefaultIdentifier.unique_saga_id(
    message,
    entity_name,
    unique_saga_id_mapping
  )
  # unique_id would be something like "order_saga:abcdef123456..."

  ```
  """

  @behaviour SagaWeaver.Identifiers.SagaIdentifier

  alias SagaWeaver.Identifiers.SagaIdentifier

  @impl SagaIdentifier
  @doc """
  Generates a unique saga identifier based on the message, entity name, and a mapping.

  This function extracts identifiers from the message using the provided mapping, hashes them, and concatenates the hash with the entity name to produce a unique identifier.

  ## Parameters

    - `message` (map): The message or event from which to extract identifiers.
    - `entity_name` (atom): The name of the saga entity.
    - `unique_saga_id_mapping` (map): A mapping of message structs to functions that extract identifiers.

  ## Returns

    - `unique_id` (String.t): A unique identifier for the saga instance.

  ## Examples

      iex> message = %MyApp.Events.OrderPlaced{order_id: 123}
      iex> entity_name = :order_saga
      iex> unique_saga_id_mapping = %{
      ...>   MyApp.Events.OrderPlaced => fn msg -> %{order_id: msg.order_id} end
      ...> }
      iex> SagaWeaver.Identifiers.DefaultIdentifier.unique_saga_id(
      ...>   message,
      ...>   entity_name,
      ...>   unique_saga_id_mapping
      ...> )
      "order_saga:a1b2c3d4e5f6g7h8i9j0..."

  """
  @spec unique_saga_id(map(), atom(), map()) :: String.t()
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

  @impl SagaIdentifier
  @doc """
  Retrieves and maps saga identifiers from a message based on the provided mapping.

  This function looks up the message's struct in the `unique_saga_id_mapping` and applies the corresponding function to extract the identifiers.

  ## Parameters

    - `message` (map): The message or event from which to extract identifiers.
    - `unique_saga_id_mapping` (map): A mapping of message structs to functions that extract identifiers.

  ## Returns

    - `saga_ids` (map): A map of identifiers extracted from the message.

  ## Examples

      iex> message = %MyApp.Events.OrderPlaced{order_id: 123}
      iex> unique_saga_id_mapping = %{
      ...>   MyApp.Events.OrderPlaced => fn msg -> %{order_id: msg.order_id} end
      ...> }
      iex> SagaWeaver.Identifiers.DefaultIdentifier.get_mapped_saga_ids(
      ...>   message,
      ...>   unique_saga_id_mapping
      ...> )
      %{order_id: 123}

  """
  @spec get_mapped_saga_ids(map(), map()) :: map()
  def get_mapped_saga_ids(message, unique_saga_id_mapping) do
    unique_saga_id_mapping[message.__struct__].(message)
  end

  defp ids_to_sha(saga_ids) do
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
