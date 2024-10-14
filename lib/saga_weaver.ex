defmodule SagaWeaver do
  @moduledoc false
  use Supervisor

  alias SagaWeaver.Orchestrator
  @impl Supervisor
  def init(_args) do
    Supervisor.init([], strategy: :one_for_one)
  end

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def execute_saga(saga, message) do
    Orchestrator.execute_saga(saga, message)
  end

  def retrieve_saga(saga, message) do
    Orchestrator.retrieve_saga(saga, message)
  end
end
