defmodule SagaWeaver.SagaBehaviour do
  @moduledoc false
  @callback entity_name() :: atom()
  @callback started_by() :: [module()]
  @callback identity_key_mapping() :: %{module() => (term() -> map())}
  @callback handle_message(SagaWeaver.SagaSchema.t(), any()) ::
              {:ok, SagaWeaver.SagaSchema.t()} | {:error, any()}
end

defmodule SagaWeaver.Saga do
  @moduledoc false
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
