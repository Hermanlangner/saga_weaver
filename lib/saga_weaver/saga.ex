defmodule SagaWeaver.SagaBehaviour do
  @moduledoc false
  @callback entity_name() :: atom()
  @callback started_by() :: [module()]
  @callback identity_key_mapping() :: %{module() => (term() -> map())}
  @callback handle_message(SagaWeaver.SagaSchema.t(), any()) ::
              {:ok, SagaWeaver.SagaSchema.t()} | {:error, any()}
end

defmodule SagaWeaver.Saga do
  @moduledoc """
  The `SagaWeaver.Saga` module provides a macro to simplify the creation of sagas within the SagaWeaver framework. By using `SagaWeaver.Saga`, developers can define sagas that orchestrate complex, long-running transactions across multiple services or operations.

  ## Overview

  A saga represents a sequence of operations that must be executed reliably and consistently, often involving compensating actions in case of failures. This module sets up the necessary boilerplate, allowing you to focus on implementing the specific logic of your saga.

  When you `use SagaWeaver.Saga`, the following happens:

  - The module is set to implement the `SagaWeaver.SagaBehaviour` behaviour.
  - Default implementations for required callbacks are provided.
  - Helper functions are injected to manage saga state and context.

  ## Usage

  To define a saga, create a module and `use SagaWeaver.Saga`, optionally providing configuration options:

  ```elixir
  defmodule MyApp.OrderSaga do
    use SagaWeaver.Saga,
      started_by: [MyApp.Events.OrderPlaced],
      identity_key_mapping: %{
        MyApp.Events.OrderPlaced => fn message -> %{order_id: message.order_id} end
      }

    @impl true
    def handle_message(saga_instance, %MyApp.Events.OrderPlaced{} = message) do
      # Implement your saga logic here
      saga_instance = assign_state(saga_instance, :order_status, :placed)
      {:ok, saga_instance}
    end

    # Optionally override other callbacks or functions as needed
  end

  ```

  ### Configuration Options
  - :started_by (optional): A list of message modules that can initiate this saga. Defaults to an empty list.
  - :identity_key_mapping (optional): A mapping that defines how to extract identifiers from messages to uniquely identify saga instances. Defaults to an empty map.

  ### Callbacks Implemented
  The following callbacks from SagaWeaver.SagaBehaviour are implemented with default or configurable behavior:

  - entity_name/0: Returns the module name as the saga's entity name.
  - started_by/0: Returns the list of message modules that can start this saga.
  - identity_key_mapping/0: Returns the mapping used to identify the saga instance.
  - handle_message/2: Handles incoming messages and updates the saga's state. Defaults to returning an error if not overridden.

  ### Helper Functions
  The module provides several functions to manage saga state and context:

  - assign_state/2: Updates the saga's state with a map of key-value pairs.
  - assign_state/3: Updates the saga's state by setting a single key-value pair.
  - assign_context/2: Updates the saga's context with a map of key-value pairs.
  - assign_context/3: Updates the saga's context by setting a single key-value pair.
  - mark_as_completed/1: Marks the saga as completed.
  These functions interact with the underlying storage adapter to persist changes.

  ### Overridable Functions
  The following functions are marked as overridable, allowing you to provide custom implementations:

  - handle_message/2
  - started_by/0
  - entity_name/0
  - identity_key_mapping/0

  """
  alias SagaWeaver.Adapters.StorageAdapter

  defmacro __using__(opts) do
    started_by = Keyword.get(opts, :started_by, [])
    how_to_find_saga = Keyword.get(opts, :identity_key_mapping, %{})

    quote do
      @behaviour SagaWeaver.SagaBehaviour

      def entity_name, do: __MODULE__

      def started_by, do: unquote(started_by)

      def identity_key_mapping do
        unquote(how_to_find_saga)
      end

      @spec handle_message(SagaWeaver.SagaSchema.t(), any()) ::
              {:ok, SagaWeaver.SagaSchema.t()} | {:error, any()}
      def handle_message(_entity, _message), do: {:error, "Message not recognized"}

      def assign_state(instance, key, value) do
        assign_state(instance, %{key => value})
      end

      defoverridable handle_message: 2,
                     started_by: 0,
                     entity_name: 0,
                     identity_key_mapping: 0

      def assign_state(instance, state_map) do
        {:ok, instance} = StorageAdapter.assign_state(instance, state_map)
        instance
      end

      def assign_context(instance, key, value) do
        assign_context(instance, %{key => value})
      end

      def assign_context(instance, context_map) do
        {:ok, instance} =
          StorageAdapter.assign_context(instance, context_map)

        instance
      end

      def mark_as_completed(instance) do
        {:ok, instance} = StorageAdapter.mark_as_completed(instance)
        instance
      end
    end
  end
end
