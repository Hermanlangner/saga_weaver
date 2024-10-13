defmodule SagaWeaver do
  @moduledoc false
  #  use Supervisor

  alias SagaWeaver.Orchestrator

  # GenServer Callbacks
  def execute_saga(saga, message) do
    Orchestrator.execute_saga(saga, message)
  end

  def retrieve_saga(saga, message) do
    Orchestrator.retrieve_saga(saga, message)
  end
end
