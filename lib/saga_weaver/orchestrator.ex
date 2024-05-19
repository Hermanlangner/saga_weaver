defmodule SagaWeaver.OrchestratorBehaviour do
  @callback execute_saga(any(), any()) :: any()
  @callback start_saga(any(), any()) :: any()
  @callback retrieve_saga(any(), any()) :: any()
  @callback initialize_saga(any(), any()) :: any()
end

defmodule SagaWeaver.Orchestrator do
  @behaviour SagaWeaver.OrchestratorBehaviour

  alias SagaWeaver.SagaSchema
  alias SagaWeaver.Identifiers.SagaIdentifier
  alias SagaWeaver.Adapters.StorageAdapter

  @impl true
  @spec execute_saga(any(), any()) :: any()
  def execute_saga(runner_module, message) do
    instance_case =
      case retrieve_saga(runner_module, message) do
        nil -> start_saga(runner_module, message)
        instance -> instance
      end

    updated_entity = runner_module.handle_message(instance_case, message)

    if updated_entity.marked_as_completed do
      StorageAdapter.complete_saga(updated_entity.unique_identifier)
      {:ok, "Saga completed"}
    end
  end

  @impl true
  @spec start_saga(any(), any()) :: any()
  def start_saga(runner_module, message) do
    if message.__struct__ in runner_module.started_by() do
      runner_module
      |> initialize_saga(message)
    else
      {:error, "Message not supported"}
    end
  end

  @impl true
  @spec initialize_saga(any(), any()) :: any()
  def initialize_saga(runner_module, message) do
    unique_saga_id =
      SagaIdentifier.unique_saga_id(
        runner_module.entity_name(),
        message,
        runner_module.identity_mapping()
      )

    initial_state = %SagaSchema{
      unique_identifier: unique_saga_id,
      saga_name: runner_module.entity_name(),
      states: %{},
      context: %{},
      marked_as_completed: false
    }

    StorageAdapter.initialize_saga(initial_state)
    initial_state
  end

  @impl true
  @spec retrieve_saga(any(), any()) :: any()
  def retrieve_saga(runner_module, message) do
    SagaIdentifier.unique_saga_id(
      runner_module.entity_name(),
      message,
      runner_module.identity_mapping()
    )
    |> StorageAdapter.get_saga()
  end
end
