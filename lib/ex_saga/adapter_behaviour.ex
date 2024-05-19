defmodule ExSaga.AdapterBehaviour do
  alias ExSaga.SagaEntity

  @callback create_saga_instance(SagaEntity.t()) :: {:ok, SagaEntity.t()} | {:error, any()}
  @callback find_saga_instance(any()) :: {:ok, SagaEntity.t()} | nil
  @callback mark_as_completed(SagaEntity.t()) :: {:ok, SagaEntity.t()} | {:error, any()}
  @callback delete_saga_instance(SagaEntity.t()) :: :ok | {:error, any()}
  @callback assign_state(SagaEntity.t(), any()) :: {:ok, SagaEntity.t()} | {:error, any()}
  @callback assign_context(SagaEntity.t(), any()) :: {:ok, SagaEntity.t()} | {:error, any()}
end
