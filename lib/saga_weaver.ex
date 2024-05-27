defmodule SagaWeaver do
  use Supervisor

  alias SagaWeaver.Producer
  alias SagaWeaver.ConsumerSupervisor

  @impl Supervisor
  def init(_args) do
    children = [
      {Redix, []},
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
end
