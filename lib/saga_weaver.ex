defmodule SagaWeaver do
  @moduledoc """
  The `SagaWeaver` module serves as the primary interface for executing and retrieving sagas within the SagaWeaver framework. It provides functions to orchestrate sagas based on incoming messages and to access existing saga instances.

  ## Overview

  - **execute_saga/2**: Executes a saga by processing a given message. It determines whether to start a new saga or continue an existing one based on the message.
  - **retrieve_saga/2**: Retrieves an existing saga instance associated with a message.

  ## Usage

  To use `SagaWeaver`, you typically have saga modules that implement the saga logic using `use SagaWeaver.Saga`. You can then execute or retrieve sagas using the functions provided by this module.

  ### Executing a Saga

  The `execute_saga/2` function is used to process a message within the context of a saga. It will either start a new saga or continue an existing one.

  **Example:**

  ```elixir
  alias MyApp.Sagas.OrderSaga
  alias MyApp.Events.OrderPlaced

  message = %OrderPlaced{order_id: 123, customer_id: 456}

  case SagaWeaver.execute_saga(OrderSaga, message) do
    {:ok, saga_instance} ->
      # Saga executed successfully
      IO.inspect(saga_instance, label: "Saga Instance")

    {:noop, reason} ->
      # No operation was performed
  end
  ```

  ### Retrieving a Saga
  The retrieve_saga/2 function allows you to fetch an existing saga instance based on a message. This is useful if you need to access the saga's state or context outside of the execution flow.

  Example:
  ```elixir
  alias MyApp.Sagas.OrderSaga
  alias MyApp.Events.OrderUpdated

  message = %OrderUpdated{order_id: 123}

  case SagaWeaver.retrieve_saga(OrderSaga, message) do
  {:ok, saga_instance} ->
    # Saga instance retrieved
    IO.inspect(saga_instance, label: "Retrieved Saga Instance")

  {:ok, :not_found} ->
    # No saga found for the given message
    IO.puts("Saga not found")

  {:error, reason} ->
    # An error occurred
  end`

  ```

  ### Notes
  - Ensure that your saga modules are properly defined using use SagaWeaver.Saga and implement the necessary callbacks.
  - The execute_saga/2 function internally uses the SagaWeaver.Orchestrator to manage saga execution.
  - The uniqueness of a saga instance is determined by the message and the saga's identity mapping. Make sure your identity mappings are correctly configured.

  ### Functions
  - execute_saga/2: Executes or continues a saga based on the provided message.
  - retrieve_saga/2: Retrieves an existing saga instance associated with a messag
  """

  use Supervisor

  alias SagaWeaver.Orchestrator
  @impl Supervisor
  def init(_args) do
    Supervisor.init([], strategy: :one_for_one)
  end

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def execute_saga(saga, message) do
    Orchestrator.execute_saga(saga, message)
  end

  def retrieve_saga(saga, message) do
    Orchestrator.retrieve_saga(saga, message)
  end
end
