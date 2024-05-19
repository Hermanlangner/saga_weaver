defmodule ExSaga.SagaBehaviour do
  @callback saga_name() :: atom()
  @callback started_by() :: [module()]
  @callback how_to_find_saga_configuration() :: %{module() => (term() -> map())}
  @callback handle_event(ExSaga.SagaEntity.t(), any()) ::
              {:ok, ExSaga.SagaEntity.t()} | {:error, any()}
end
