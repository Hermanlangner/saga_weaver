defmodule SagaWeaver do
  @moduledoc false
  use Supervisor

  alias SagaWeaver.ConsumerSupervisor
  alias SagaWeaver.Orchestrator
  alias SagaWeaver.Producer

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
    Orchestrator.retrieve_saga(saga, message)
  end
end
