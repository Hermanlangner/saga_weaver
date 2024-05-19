defmodule SagaWeaver.Behaviours.Adapter do
  alias SagaWeaver.SagaSchema

  @callback initialize_saga(SagaSchema.t()) :: {:ok, SagaSchema.t()} | {:error, any()}
  @callback get_saga(any()) :: {:ok, SagaSchema.t()} | nil
  @callback mark_as_completed(SagaSchema.t()) :: {:ok, SagaSchema.t()} | {:error, any()}
  @callback complete_saga(SagaSchema.t()) :: :ok | {:error, any()}
  @callback assign_state(SagaSchema.t(), any()) :: {:ok, SagaSchema.t()} | {:error, any()}
  @callback assign_context(SagaSchema.t(), any()) :: {:ok, SagaSchema.t()} | {:error, any()}
end
