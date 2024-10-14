defmodule SagaWeaver.Adapters.StorageAdapter do
  @moduledoc """
  The `SagaWeaver.Adapters.StorageAdapter` module defines the behaviour and provides an interface for storage adapters used by the SagaWeaver framework.

  ## Overview

  SagaWeaver allows for pluggable storage backends to persist saga state and context. This module specifies the required callbacks that any storage adapter must implement to integrate with the framework. By abstracting the storage layer, SagaWeaver can support different storage systems like Redis, PostgreSQL, or custom solutions.

  ## Responsibilities

  - **Define Behaviour**: Specifies the set of functions (callbacks) that a storage adapter must implement.
  - **Delegation**: Provides default implementations that delegate function calls to the configured storage adapter module.

  ## Callbacks

  Storage adapters must implement the following callbacks:

  - `initialize_saga/1`: Initializes and persists a new saga instance.
  - `saga_exists?/1`: Checks if a saga with the given identifier exists.
  - `get_saga/1`: Retrieves a saga instance by its unique identifier.
  - `mark_as_completed/1`: Marks a saga as completed without deleting it.
  - `complete_saga/1`: Completes and removes a saga from storage.
  - `assign_state/2`: Updates the saga's state data.
  - `assign_context/2`: Updates the saga's context data.

  ## Usage

  Developers can implement custom storage adapters by creating a module that implements this behaviour. The custom adapter must be configured in the application configuration.

  ### Example Implementation

  ```elixir
  defmodule MyApp.CustomStorageAdapter do
    @behaviour SagaWeaver.Adapters.StorageAdapter

    alias SagaWeaver.SagaSchema

    @impl true
    def initialize_saga(saga_schema) do
      # Custom logic to initialize and store the saga
    end

    @impl true
    def saga_exists?(key) do
      # Custom logic to check if the saga exists
    end

    # Implement other callbacks...
  end
  ```

  ### Configuration
  To use a custom storage adapter, set it in your application's configuration:
  ```elixir
  config :saga_weaver, :storage_adapter, MyApp.CustomStorageAdapter
  ```

  The impl/0 function in SagaWeaver.Adapters.StorageAdapter retrieves the configured adapter and delegates the function calls.

  ## Default Implementation
  By default, SagaWeaver may provide built-in adapters like RedisAdapter or PostgresAdapter. If none is configured, you need to specify one to enable saga persistence.

  """
  alias SagaWeaver.{Config, SagaSchema}

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

  defp impl, do: Config.storage_adapter()
end
