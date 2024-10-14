defmodule SagaWeaver.Orchestrator do
  @moduledoc """
  The `SagaWeaver.Orchestrator` module is responsible for orchestrating the execution of sagas within the SagaWeaver framework. It handles the initiation, retrieval, execution, and completion of saga instances based on incoming messages.

  ## Overview

  - **Execute Saga**: Determines whether to start a new saga or continue an existing one based on the incoming message.
  - **Handle Saga**: Processes the saga by invoking the appropriate handler and manages its state.
  - **Start Saga**: Initializes a new saga instance if the message is eligible to start a saga.
  - **Initialize Saga**: Sets up the initial state of a new saga and stores it using the configured storage adapter.
  - **Retrieve Saga**: Fetches an existing saga instance based on a unique identifier derived from the message.

  ## Key Functions

  - `execute_saga/2`: Entry point for processing messages and orchestrating sagas.
  - `handle_saga/3`: Handles the saga logic, updating its state, and marking it as completed if necessary.
  - `start_saga/2`: Checks if a message can start a new saga and initializes it.
  - `initialize_saga/2`: Creates and stores a new saga instance.
  - `retrieve_saga/2`: Retrieves an existing saga instance based on the message.

  ## Usage

  The `Orchestrator` module is typically not used directly by end-users but is invoked by the SagaWeaver framework when messages are processed.

  ## Examples

  ```elixir
  # Assuming `MySaga` is a module that uses SagaWeaver
  message = %MyApp.SomeEvent{}
  SagaWeaver.Orchestrator.execute_saga(MySaga, message)
  ```

  ## Dependencies
  SagaWeaver.Adapters.StorageAdapter: Interface for storage operations.
  SagaWeaver.Identifiers.SagaIdentifier: Generates unique identifiers for sagas.
  SagaWeaver.SagaSchema: Defines the saga's data structure.
  """
  alias SagaWeaver.Adapters.StorageAdapter
  alias SagaWeaver.Identifiers.SagaIdentifier
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
  @spec execute_saga(atom(), map()) :: {:ok, SagaSchema.t()} | {:noop, String.t()}
  def execute_saga(saga, message) do
    fetch_saga_result =
      case retrieve_saga(saga, message) do
        {:ok, :not_found} -> start_saga(saga, message)
        {:ok, instance} -> {:ok, instance}
      end

    case fetch_saga_result do
      {:ok, instance} -> handle_saga(saga, instance, message)
      {:noop, reason} -> {:noop, reason}
    end
  end

  defp handle_saga(saga, instance, message) do
    {:ok, updated_entity} = saga.handle_message(instance, message)

    if updated_entity.marked_as_completed do
      StorageAdapter.complete_saga(updated_entity)
      {:ok, updated_entity}
    else
      {:ok, updated_entity}
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
  @spec start_saga(atom(), map()) :: {:ok, SagaSchema.t()} | {:ok, :not_found} | {:ok, String.t()}
  def start_saga(saga, message) do
    if message.__struct__ in saga.started_by() do
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
  @spec initialize_saga(atom(), map()) :: {:ok, SagaSchema.t()} | {:ok, :not_found}
  def initialize_saga(saga, message) do
    unique_saga_id =
      SagaIdentifier.unique_saga_id(
        message,
        saga.entity_name(),
        saga.identity_key_mapping()
      )

    initial_state = %SagaSchema{
      uuid: unique_saga_id,
      saga_name: to_string(saga.entity_name()),
      states: %{},
      context: %{},
      marked_as_completed: false
    }

    StorageAdapter.initialize_saga(initial_state)
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
  @spec retrieve_saga(atom(), map()) :: {:ok, SagaSchema.t()} | {:ok, :not_found}
  def retrieve_saga(saga, message) do
    SagaIdentifier.unique_saga_id(
      message,
      saga.entity_name(),
      saga.identity_key_mapping()
    )
    |> StorageAdapter.get_saga()
  end
end
