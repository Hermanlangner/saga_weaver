defmodule SagaWeaver.Behaviours.SagaOrchestrator do
  @callback execute_saga(any(), any()) :: any()
  @callback start_saga(any(), any()) :: any()
  @callback retrieve_saga(any(), any()) :: any()
  @callback initialize_saga(any(), any()) :: any()
end
