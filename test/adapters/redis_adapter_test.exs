defmodule SagaWeaver.Adapters.RedisAdapterTest do
  use ExUnit.Case, async: true
  alias SagaWeaver.Adapters.RedisAdapter
  alias SagaWeaver.SagaSchema

  setup_all do
    {:ok, conn} = Redix.start_link(sync_connect: true)
    Redix.command!(conn, ["FLUSHALL"])
    :ok = Redix.stop(conn)
    :ok
  end

  test "initializes a saga" do
    saga = %SagaSchema{
      unique_identifier: "saga_1",
      saga_name: :example,
      states: %{},
      context: %{},
      marked_as_completed: false
    }

    assert {:ok, _saga} = RedisAdapter.initialize_saga(saga)
    assert {:ok, ^saga} = RedisAdapter.get_saga("saga_1")
  end

  test "marks a saga as completed" do
    saga = %SagaSchema{
      unique_identifier: "saga_2",
      saga_name: :example,
      states: %{},
      context: %{},
      marked_as_completed: false
    }

    RedisAdapter.initialize_saga(saga)
    assert {:ok, _} = RedisAdapter.mark_as_completed(saga)
    assert {:ok, updated_saga} = RedisAdapter.get_saga("saga_2")
    assert updated_saga.marked_as_completed
  end

  test "deletes a completed saga" do
    saga = %SagaSchema{
      unique_identifier: "saga_3",
      saga_name: :example,
      states: %{},
      context: %{},
      marked_as_completed: false
    }

    RedisAdapter.initialize_saga(saga)
    assert :ok = RedisAdapter.complete_saga(saga)
    assert {:ok, nil} = RedisAdapter.get_saga("saga_3")
  end

  test "assigns state to a saga" do
    saga = %SagaSchema{
      unique_identifier: "saga_4",
      saga_name: :example,
      states: %{},
      context: %{},
      marked_as_completed: false
    }

    RedisAdapter.initialize_saga(saga)
    state = %{step: "step_1"}
    assert {:ok, updated_saga} = RedisAdapter.assign_state(saga, state)
    assert updated_saga.states == state
  end

  test "assigns context to a saga" do
    saga = %SagaSchema{
      unique_identifier: "saga_5",
      saga_name: :example,
      states: %{},
      context: %{},
      marked_as_completed: false
    }

    RedisAdapter.initialize_saga(saga)
    context = %{user: "user_1"}
    assert {:ok, updated_saga} = RedisAdapter.assign_context(saga, context)
    assert updated_saga.context == context
  end
end
