defmodule ExSaga.SagaBehaviour do
  @callback run_saga(any()) :: any()
  @callback start_saga(any()) :: any()
  @callback find_saga_instance(any()) :: any()
  @callback create_instance(any()) :: any()
end
