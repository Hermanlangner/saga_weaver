defmodule SagaWeaver.Adapters.PostgresAdapterTest do
  use SagaWeaver.DataCase

  alias SagaWeaver.Adapters.PostgresAdapter
  alias SagaWeaver.SagaSchema

  setup_all do
    Application.put_env(SagaWeaver, :storage_adapter, SagaWeaver.Adapters.PostgresAdapter)
    :ok
  end

  test "saga_exists?/1 returns false when no saga exists" do
    assert PostgresAdapter.saga_exists?("1234") == false
  end

  test "saga_exists?/1 returns true when saga exists" do
    saga = %SagaSchema{
      uuid: "1234",
      saga_name: "test_saga"
    }

    assert {:ok, _saga} = PostgresAdapter.try_create_saga(saga)
    assert PostgresAdapter.saga_exists?("1234")
  end

  test "initialize_saga/1 creates a new saga when no saga exists" do
    saga = %SagaSchema{
      uuid: "1234",
      saga_name: "test_saga"
    }

    assert {:ok, _saga} = PostgresAdapter.initialize_saga(saga)
    assert PostgresAdapter.saga_exists?("1234")
  end

  test "try_create_saga/1 creates a new saga" do
    saga = %SagaSchema{
      uuid: "1234",
      saga_name: "test_saga"
    }

    assert {:ok, _saga} = PostgresAdapter.try_create_saga(saga)
    assert PostgresAdapter.saga_exists?("1234")
  end

  test "try_create_saga/1 returns existing saga when saga already exists" do
    saga = %SagaSchema{
      uuid: "1234",
      saga_name: "test_saga"
    }

    assert {:ok, _saga} = PostgresAdapter.try_create_saga(saga)
    assert {:ok, _saga} = PostgresAdapter.try_create_saga(saga)
    assert PostgresAdapter.saga_exists?("1234")
  end

  test "complete_saga/1 delete existing saga returns :ok" do
    saga = %SagaSchema{
      uuid: "1234",
      saga_name: "test_saga"
    }

    assert {:ok, created_saga} = PostgresAdapter.try_create_saga(saga)
    assert PostgresAdapter.saga_exists?("1234")

    assert :ok = PostgresAdapter.complete_saga(created_saga)
    assert PostgresAdapter.saga_exists?("1234") == false
  end

  test "complete_saga/1 delete non existant saga returns :ok" do
    saga = %SagaSchema{
      uuid: "1234",
      saga_name: "test_saga"
    }

    assert {:ok, created_saga} = PostgresAdapter.try_create_saga(saga)
    assert PostgresAdapter.saga_exists?("1234")

    assert :ok = PostgresAdapter.complete_saga(created_saga)
    assert PostgresAdapter.saga_exists?("1234") == false

    assert :ok = PostgresAdapter.complete_saga(created_saga)
    assert PostgresAdapter.saga_exists?("1234") == false
  end

  test "mark_as_completed/1 marks a saga as completed" do
    saga = %SagaSchema{
      uuid: "1234",
      saga_name: "test_saga"
    }

    assert {:ok, created_saga} = PostgresAdapter.try_create_saga(saga)
    assert PostgresAdapter.saga_exists?("1234")

    assert {:ok, updated_saga} =
             PostgresAdapter.mark_as_completed(created_saga)

    assert updated_saga.marked_as_completed
  end

  test "assign_state updates state for existing saga" do
    saga = %SagaSchema{
      uuid: "1234",
      saga_name: "test_saga"
    }

    assert {:ok, created_saga} = PostgresAdapter.try_create_saga(saga)
    assert PostgresAdapter.saga_exists?("1234")

    state = %{
      "key" => "value"
    }

    assert {:ok, updated_saga} =
             PostgresAdapter.assign_state(created_saga, state)

    assert updated_saga.states == state
  end

  test "assign_context updates context for existing saga" do
    saga = %SagaSchema{
      uuid: "1234",
      saga_name: "test_saga"
    }

    assert {:ok, created_saga} = PostgresAdapter.try_create_saga(saga)
    assert PostgresAdapter.saga_exists?("1234")

    context = %{
      "key" => "value"
    }

    assert {:ok, updated_saga} =
             PostgresAdapter.assign_context(created_saga, context)

    assert updated_saga.context == context
  end
end
