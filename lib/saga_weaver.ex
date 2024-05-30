defmodule SagaWeaver do
  use Supervisor

  alias SagaWeaver.Producer
  alias SagaWeaver.ConsumerSupervisor

  @impl Supervisor
  def init(_args) do
    children = [
      {Producer, []},
      {ConsumerSupervisor, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GenServer Callbacks
  def execute_saga(saga, message) do
    GenServer.call(Producer, {:execute_saga, saga, message}, :infinity)
  end

  def retrieve_saga(saga, message) do
    unique_saga_id =
      SagaWeaver.Identifiers.DefaultIdentifier.unique_saga_id(
        message,
        saga.entity_name(),
        saga.identity_key_mapping()
      )

    SagaWeaver.Adapters.StorageAdapter.get_saga(unique_saga_id)
  end
end
