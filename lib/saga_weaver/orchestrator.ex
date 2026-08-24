defmodule SagaWeaver.Orchestrator do
  @moduledoc """
  Compatibility orchestration for SagaWeaver 0.2 applications.

  New code should call `SagaWeaver.handle/2` or an application-owned facade.
  This module preserves the old callback, identifier, return, and
  delete-on-completion behavior while existing applications migrate.
  """
  alias SagaWeaver.Adapters.StorageAdapter
  alias SagaWeaver.Compatibility
  alias SagaWeaver.SagaSchema

  @doc """
  Executes a saga by processing the given message.

  This function serves as the entry point for handling messages within a saga context. It determines whether to start a new saga or continue an existing one based on the message.

  ## Parameters

    - `saga_module` (atom): The saga module that defines the saga logic.
    - `message` (map): The message or event to be processed.

  ## Returns

    - `{:ok, saga_instance}`: Indicates the saga was successfully processed.
    - `{:noop, reason}`: No operation was performed, with a reason provided.

  ## Examples

      iex> SagaWeaver.Orchestrator.execute_saga(MyApp.OrderSaga, message)
      {:ok, %SagaSchema{}}

  """
  @spec execute_saga(module(), map()) ::
          {:ok, SagaSchema.t()} | {:noop, String.t()} | {:error, term()}
  def execute_saga(saga, message) do
    fetch_saga_result =
      case retrieve_saga(saga, message) do
        {:ok, :not_found} -> start_saga(saga, message)
        {:ok, instance} -> {:ok, instance}
        {:error, reason} -> {:error, reason}
      end

    case fetch_saga_result do
      {:ok, instance} -> handle_saga(saga, instance, message)
      {:noop, reason} -> {:noop, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_saga(saga, instance, message) do
    case saga.handle_message(instance, message) do
      {:ok, %SagaSchema{} = updated_entity} ->
        if updated_entity.marked_as_completed do
          StorageAdapter.complete_saga(updated_entity)
        end

        {:ok, updated_entity}

      {:error, reason} ->
        {:error, reason}

      invalid ->
        {:error, {:invalid_callback_result, invalid}}
    end
  end

  @doc """
  Starts a new saga if the message is eligible to initiate one.

  This function checks whether the incoming message is among those that can start a new saga, as defined by the `started_by/0` callback in the saga module.

  ## Parameters

    - `saga_module` (atom): The saga module.
    - `message` (map): The message that may start a new saga.

  ## Returns

    - `{:ok, saga_instance}`: A new saga has been initialized.
    - `{:noop, reason}`: The message does not start a saga.

  ## Examples

      iex> SagaWeaver.Orchestrator.start_saga(MyApp.OrderSaga, start_message)
      {:ok, %SagaSchema{}}

  """
  @spec start_saga(module(), map()) ::
          {:ok, SagaSchema.t()} | {:noop, String.t()} | {:error, term()}
  def start_saga(saga, message) do
    if Map.get(message, :__struct__) in saga.started_by() do
      saga
      |> initialize_saga(message)
    else
      {:noop,
       "No active Sagas were found for this message, this message also does not start a new Saga."}
    end
  end

  @doc """
  Initializes a new saga instance with initial state.

  Creates a new saga instance using the provided message and stores it using the configured storage adapter.

  ## Parameters

    - `saga_module` (atom): The saga module.
    - `message` (map): The message that starts the saga.

  ## Returns

    - `{:ok, saga_instance}`: The new saga instance.
    - `{:ok, :not_found}`: No saga instance was found.

  ## Examples

      iex> SagaWeaver.Orchestrator.initialize_saga(MyApp.OrderSaga, start_message)
      {:ok, %SagaSchema{}}

  """
  @spec initialize_saga(module(), map()) :: {:ok, SagaSchema.t()} | {:error, term()}
  def initialize_saga(saga, message) do
    with {:ok, unique_saga_id} <- Compatibility.v1_key(saga, message) do
      initial_state = %SagaSchema{
        uuid: unique_saga_id,
        saga_name: to_string(saga.entity_name()),
        states: %{},
        context: %{},
        marked_as_completed: false
      }

      StorageAdapter.initialize_saga(initial_state)
    end
  end

  @doc """
  Retrieves an existing saga instance based on the message.

  Generates a unique saga identifier from the message and attempts to retrieve the saga from storage.

  ## Parameters

    - `saga_module` (atom): The saga module.
    - `message` (map): The message associated with the saga.

  ## Returns

    - `{:ok, saga_instance}`: The existing saga instance.
    - `{:ok, :not_found}`: No saga instance was found.

  ## Examples

      iex> SagaWeaver.Orchestrator.retrieve_saga(MyApp.OrderSaga, message)
      {:ok, %SagaSchema{}}

  """
  @spec retrieve_saga(module(), map()) ::
          {:ok, SagaSchema.t()} | {:ok, :not_found} | {:error, term()}
  def retrieve_saga(saga, message) do
    with {:ok, unique_saga_id} <- Compatibility.v1_key(saga, message) do
      StorageAdapter.get_saga(unique_saga_id)
    end
  end
end
