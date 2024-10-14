defmodule SagaWeaver.Adapters.StorageAdapter do
  @moduledoc false
  alias SagaWeaver.Adapters.RedisAdapter
  alias SagaWeaver.SagaSchema

  @callback initialize_saga(SagaSchema.t()) ::
              {:ok, SagaSchema.t()} | {:error, Ecto.Changeset.t()}
  @callback saga_exists?(String.t()) :: boolean
  @callback get_saga(String.t()) :: {:ok, SagaSchema.t()} | {:ok, :not_found}
  @callback mark_as_completed(SagaSchema.t()) :: {:ok, SagaSchema.t()}
  @callback complete_saga(SagaSchema.t()) :: :ok
  @callback assign_state(SagaSchema.t(), map()) :: {:ok, SagaSchema.t()}
  @callback assign_context(SagaSchema.t(), map()) :: {:ok, SagaSchema.t()}

  @spec initialize_saga(SagaSchema.t()) :: {:ok, SagaSchema.t()} | {:error, Ecto.Changeset.t()}
  def initialize_saga(saga_schema), do: impl().initialize_saga(saga_schema)

  @spec saga_exists?(any()) :: boolean()
  def saga_exists?(key), do: impl().saga_exists?(key)

  @spec get_saga(String.t()) :: {:ok, SagaSchema.t()} | {:ok, :not_found}
  def get_saga(key), do: impl().get_saga(key)

  @spec mark_as_completed(SagaSchema.t()) :: {:ok, SagaSchema.t()}
  def mark_as_completed(saga_schema), do: impl().mark_as_completed(saga_schema)

  @spec complete_saga(SagaSchema.t()) :: :ok
  def complete_saga(saga_schema), do: impl().complete_saga(saga_schema)

  @spec assign_state(SagaSchema.t(), map()) :: {:ok, SagaSchema.t()}
  def assign_state(saga_schema, state), do: impl().assign_state(saga_schema, state)

  @spec assign_context(SagaSchema.t(), map()) :: {:ok, SagaSchema.t()}
  def assign_context(saga_schema, context), do: impl().assign_context(saga_schema, context)

  defp impl, do: RedisAdapter
end
