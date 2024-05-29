defmodule SagaWeaver.Adapters.StorageAdapter do
  alias SagaWeaver.Adapters.RedisAdapter
  alias SagaWeaver.SagaSchema

  @callback initialize_saga(SagaSchema.t()) :: {:ok, SagaSchema.t()} | {:error, any()}
  @callback saga_exists?(any()) :: boolean
  @callback get_saga(any()) :: {:ok, SagaSchema.t()} | nil
  @callback mark_as_completed(SagaSchema.t()) :: {:ok, SagaSchema.t()} | {:error, any()}
  @callback complete_saga(SagaSchema.t()) :: :ok | {:error, any()}
  @callback assign_state(SagaSchema.t(), any()) :: {:ok, SagaSchema.t()} | {:error, any()}
  @callback assign_context(SagaSchema.t(), any()) :: {:ok, SagaSchema.t()} | {:error, any()}

  @spec initialize_saga(any()) :: {:error, any()} | {:ok, SagaWeaver.SagaSchema.t()}
  def initialize_saga(saga_schema), do: impl().initialize_saga(saga_schema)

  @spec saga_exists?(any()) :: boolean
  def saga_exists?(key), do: impl().saga_exists?(key)

  @spec get_saga(any()) :: nil | {:error, any()} | {:ok, any()}
  def get_saga(key), do: impl().get_saga(key)

  @spec mark_as_completed(any()) :: {:error, any()} | {:ok, SagaWeaver.SagaSchema.t()}
  def mark_as_completed(saga_schema), do: impl().mark_as_completed(saga_schema)

  @spec complete_saga(any()) :: {:error, any()} | :ok
  def complete_saga(saga_schema), do: impl().complete_saga(saga_schema)

  @spec assign_state(any(), any()) :: {:error, any()} | {:ok, SagaWeaver.SagaSchema.t()}
  def assign_state(saga_schema, state), do: impl().assign_state(saga_schema, state)

  @spec assign_context(any(), any()) :: {:error, any()} | {:ok, SagaWeaver.SagaSchema.t()}
  def assign_context(saga_schema, context), do: impl().assign_context(saga_schema, context)

  defp impl, do: RedisAdapter
end
