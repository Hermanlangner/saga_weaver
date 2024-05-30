defmodule SagaWeaver.Orchestrator do
  alias SagaWeaver.SagaSchema
  alias SagaWeaver.Identifiers.SagaIdentifier
  alias SagaWeaver.Adapters.StorageAdapter

  @spec execute_saga(atom(), map()) :: any()
  def execute_saga(saga, message) do
    {:ok, instance_case} =
      case retrieve_saga(saga, message) do
        {:ok, :not_found} -> start_saga(saga, message)
        {:ok, instance} -> {:ok, instance}
      end

    {:ok, updated_entity} = saga.handle_message(instance_case, message)

    if updated_entity.marked_as_completed do
      StorageAdapter.complete_saga(updated_entity)
      {:ok, updated_entity}
    else
      {:ok, updated_entity}
    end
  end

  @spec start_saga(any(), any()) :: any()
  def start_saga(saga, message) do
    if message.__struct__ in saga.started_by() do
      saga
      |> initialize_saga(message)
    else
      {:ok,
       "No active Sagas were found for this message, this message also does not start a new Saga."}
    end
  end

  @spec initialize_saga(any(), any()) :: any()
  def initialize_saga(saga, message) do
    unique_saga_id =
      SagaIdentifier.unique_saga_id(
        message,
        saga.entity_name(),
        saga.identity_key_mapping()
      )

    initial_state = %SagaSchema{
      unique_identifier: unique_saga_id,
      saga_name: saga.entity_name(),
      states: %{},
      context: %{},
      marked_as_completed: false
    }

    StorageAdapter.initialize_saga(initial_state)
  end

  @spec retrieve_saga(any(), any()) :: any()
  def retrieve_saga(saga, message) do
    SagaIdentifier.unique_saga_id(
      message,
      saga.entity_name(),
      saga.identity_key_mapping()
    )
    |> StorageAdapter.get_saga()
  end
end
