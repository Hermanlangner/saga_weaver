defmodule SagaWeaver.OrchestratorTest do
  use ExUnit.Case, async: true

  alias SagaWeaver.Adapters.StorageAdapter
  alias SagaWeaver.Identifiers
  alias SagaWeaver.Orchestrator
  alias SagaWeaver.SagaSchema

  setup_all do
    {:ok, conn} = Redix.start_link("redis://localhost:6379")

    Application.put_env(:saga_weaver, SagaWeaver,
      host: "localhost",
      port: 6379,
      namespace: "saga_weaver_test",
      storage_adapter: SagaWeaver.Adapters.RedisAdapter
    )

    {:ok, conn: conn}
  end

  setup context do
    on_exit(fn ->
      Redix.command(context[:conn], ["FLUSHALL"])
    end)

    :ok
  end

  defmodule TestSaga do
    alias SagaWeaver.OrchestratorTest.TestMessage
    def entity_name, do: "test_saga"
    def started_by, do: [TestMessage]
    def identity_key_mapping, do: %{TestMessage => &%{id: &1.id}}

    def handle_message(%SagaSchema{} = saga, _message) do
      updated_saga = %SagaSchema{saga | marked_as_completed: true}
      {:ok, updated_saga}
    end
  end

  defmodule TestMessage do
    defstruct [:id, :name]
  end

  defmodule UnsupportedMessage do
    defstruct [:id, :name]
  end

  setup_all do
    Application.put_env(:saga_weaver, SagaWeaver.Adapters.StorageAdapter, RedisAdapter)
    :ok
  end

  describe "execute_saga/2" do
    test "starts a new saga if it does not exist" do
      message = %TestMessage{id: 1, name: "test"}
      saga = TestSaga

      uuid =
        Identifiers.DefaultIdentifier.unique_saga_id(
          message,
          saga.entity_name(),
          saga.identity_key_mapping()
        )

      {:ok, result} = Orchestrator.execute_saga(saga, message)

      assert result.uuid == uuid
      assert result.marked_as_completed
    end

    test "retrieves and handles an existing saga" do
      message = %TestMessage{id: 2, name: "test"}
      saga = TestSaga

      uuid =
        Identifiers.DefaultIdentifier.unique_saga_id(
          message,
          saga.entity_name(),
          saga.identity_key_mapping()
        )

      initial_saga = %SagaSchema{
        uuid: uuid,
        saga_name: "test_saga",
        states: %{},
        context: %{},
        marked_as_completed: false
      }

      StorageAdapter.initialize_saga(initial_saga)
      assert {:ok, _entity} = Orchestrator.execute_saga(saga, message)

      {:ok, result} = StorageAdapter.get_saga(uuid)

      assert result == :not_found
    end
  end

  describe "start_saga/2" do
    test "starts a saga if the message is supported" do
      message = %TestMessage{id: 3, name: "test"}
      saga = TestSaga

      _uuid =
        Identifiers.DefaultIdentifier.unique_saga_id(
          message,
          saga.entity_name(),
          saga.identity_key_mapping()
        )

      assert {:ok,
              %SagaSchema{
                uuid: _uuid,
                saga_name: "test_saga",
                marked_as_completed: false
              }} = Orchestrator.start_saga(saga, message)
    end

    test "returns an error if the message is not supported", _context do
      message = %UnsupportedMessage{id: 4, name: "test"}
      saga = TestSaga

      assert {:noop,
              "No active Sagas were found for this message, this message also does not start a new Saga."} =
               Orchestrator.start_saga(saga, message)
    end
  end

  describe "initialize_saga/2" do
    test "initializes a new saga" do
      message = %TestMessage{id: 5, name: "test"}
      saga = TestSaga

      uuid =
        Identifiers.DefaultIdentifier.unique_saga_id(
          message,
          saga.entity_name(),
          saga.identity_key_mapping()
        )

      Orchestrator.initialize_saga(saga, message)

      {:ok, saga} = StorageAdapter.get_saga(uuid)

      assert saga.uuid == uuid
      assert saga.saga_name == "test_saga"
      assert saga.marked_as_completed == false
    end
  end

  describe "retrieve_saga/2" do
    test "retrieves an existing saga" do
      message = %TestMessage{id: 6, name: "test"}
      saga = TestSaga

      uuid =
        Identifiers.DefaultIdentifier.unique_saga_id(
          message,
          saga.entity_name(),
          saga.identity_key_mapping()
        )

      initial_saga = %SagaSchema{
        uuid: uuid,
        saga_name: "test_saga",
        states: %{},
        context: %{},
        marked_as_completed: false
      }

      StorageAdapter.initialize_saga(initial_saga)
      assert {:ok, ^initial_saga} = Orchestrator.retrieve_saga(saga, message)
    end

    test "returns nil if the saga does not exist", _context do
      message = %TestMessage{id: 7, name: "test"}
      saga = TestSaga

      assert {:ok, :not_found} == Orchestrator.retrieve_saga(saga, message)
    end
  end
end
