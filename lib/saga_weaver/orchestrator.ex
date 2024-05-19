defmodule SagaWeaver.SagaRunner do
  @behaviour SagaWeaver.SagaBehavior

  alias SagaWeaver.{RedisAdapter, SagaEntity, TestEvent1, TestEvent2}
  alias SagaWeaver.Identifier

  @impl true
  @spec run_saga(any(), any()) :: any()
  def run_saga(runner_module, event) do
    instance_case =
      case find_saga_instance(runner_module, event) do
        nil -> start_saga(runner_module, event)
        instance -> instance
      end

    updated_entity = runner_module.handle_event(instance_case, event)

    if updated_entity.marked_as_completed do
      RedisAdapter.delete_saga_instance(updated_entity.unique_identifier)
      {:ok, "Saga completed"}
    end
  end

  @impl true
  @spec start_saga(any(), any()) :: any()
  def start_saga(runner_module, event) do
    if event.__struct__ in runner_module.started_by() do
      runner_module
      |> create_instance(event)
    else
      {:error, "Event not supported"}
    end
  end

  @impl true
  @spec create_instance(any(), any()) :: any()
  def create_instance(runner_module, event) do
    instance_name =
      Identifier.instance_name(
        runner_module.entity_name(),
        event,
        runner_module.identity_mapping()
      )

    initial_state = %SagaEntity{
      unique_identifier: instance_name,
      saga_name: runner_module.entity_name(),
      states: %{},
      context: %{},
      marked_as_completed: false
    }

    RedisAdapter.create_saga_instance(initial_state)
    initial_state
  end

  @impl true
  @spec find_saga_instance(any(), any()) :: any()
  def find_saga_instance(runner_module, event) do
    Identifier.instance_name(
      runner_module.entity_name(),
      event,
      runner_module.identity_mapping()
    )
    |> RedisAdapter.find_saga_instance()
  end
end
