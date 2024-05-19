defmodule SagaWeaver.SagaBehaviour do
  @callback saga_name() :: atom()
  @callback started_by() :: [module()]
  @callback how_to_find_saga_configuration() :: %{module() => (term() -> map())}
  @callback handle_event(SagaWeaver.SagaEntity.t(), any()) ::
              {:ok, SagaWeaver.SagaEntity.t()} | {:error, any()}
end
