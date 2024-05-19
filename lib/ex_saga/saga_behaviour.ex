defmodule ExSaga.SagaBehavior do
  @callback entity_name() :: atom()
  @callback instance_name(any()) :: String.t()
  @callback started_by() :: list(module())
  @callback run_saga(any()) :: any()
  @callback start_saga(any()) :: any()
  @callback mark_as_completed(ExSaga.SagaEntity.t()) :: any()
  @callback handle_event(ExSaga.SagaEntity.t(), any()) :: any()
  @callback find_saga_instance(any()) :: any()
  @callback create_instance(any()) :: any()
end
