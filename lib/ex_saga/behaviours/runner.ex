defmodule ExSaga.Behaviours.SagaRunner do
  @callback entity_name() :: atom()
  @callback started_by() :: [module()]
  @callback identity_key_mapping() :: %{module() => (term() -> map())}
  @callback handle_event(ExSaga.SagaEntity.t(), any()) ::
              {:ok, ExSaga.SagaEntity.t()} | {:error, any()}
end
