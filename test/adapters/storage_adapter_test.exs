defmodule SagaWeaver.Adapters.StorageAdapterTest do
  @moduledoc """
   While only the RedisAdapter is implemented completely, The StorageAdapterTests will mostly test scenarios all adapters should be able to handle.
  """
  use ExUnit.Case, async: true
  alias SagaWeaver.Adapters.StorageAdapter
  alias SagaWeaver.SagaSchema

  setup_all do
    {:ok, conn} = Redix.start_link("redis://localhost:6379")
    {:ok, conn: conn}
  end

  setup context do
    on_exit(fn ->
      Redix.command(context[:conn], ["FLUSHALL"])
    end)

    :ok
  end

  defp create_saga(id, name) do
    %SagaSchema{
      unique_identifier: "#{name}:#{id}",
      saga_name: name,
      states: %{},
      context: %{},
      marked_as_completed: false
    }
  end

  describe "initialize_saga/1" do
    test "Multiple initializes all return the latest instance instead of initializing", context do
      saga = create_saga(1, "example_saga")

      result_list =
        Task.async_stream(
          1..100,
          fn _index ->
            {:ok, result} = StorageAdapter.initialize_saga(saga)
            result
          end,
          max_concurrency: 100
        )
        |> Enum.map(fn {_response_code, result} -> result end)

      assert Enum.all?(result_list, fn created_saga -> created_saga == saga end)
    end
  end

  describe "get_saga/1" do
    test "returns a saga if it exists", context do
      saga = create_saga(2, "example_saga")
      {:ok, _} = StorageAdapter.initialize_saga(saga)

      assert {:ok, ^saga} = StorageAdapter.get_saga(saga.unique_identifier)
    end

    test "returns nil if saga does not exist", _context do
      assert nil == StorageAdapter.get_saga("nonexistent_saga")
    end
  end

  describe "saga_exists?/1" do
    test "returns a saga if it exists", context do
      saga = create_saga(2, "example_saga")
      {:ok, _} = StorageAdapter.initialize_saga(saga)

      assert true == StorageAdapter.saga_exists?(saga.unique_identifier)
    end

    test "returns nil if saga does not exist", _context do
      assert false == StorageAdapter.saga_exists?("nonexistent_saga")
    end
  end

  describe "mark_as_completed/1" do
    test "marks a saga as completed", context do
      saga = create_saga(3, "example_saga")
      {:ok, _} = StorageAdapter.initialize_saga(saga)

      {:ok, updated_saga} = StorageAdapter.mark_as_completed(saga)
      assert updated_saga.marked_as_completed

      {:ok, result} = StorageAdapter.get_saga(saga.unique_identifier)
      assert result == updated_saga
    end

    test "marks a saga as completed during high concurrency", context do
      saga = create_saga(33, "example_saga")
      {:ok, _} = StorageAdapter.initialize_saga(saga)

      result_list =
        Task.async_stream(
          1..100,
          fn _index ->
            {:ok, result} = StorageAdapter.mark_as_completed(saga)
            result
          end,
          max_concurrency: 100
        )
        |> Enum.map(fn {_response_code, result} -> result end)

      {:ok, updated_saga} = StorageAdapter.get_saga(saga.unique_identifier)
      assert Enum.all?(result_list, fn created_saga -> created_saga == updated_saga end)
    end
  end

  describe "complete_saga/1" do
    test "completes (deletes) a saga", context do
      saga = create_saga(4, "example_saga")
      {:ok, _} = StorageAdapter.initialize_saga(saga)

      assert :ok = StorageAdapter.complete_saga(saga)

      {:ok, result} = Redix.command(context[:conn], ["GET", saga.unique_identifier])
      assert result == nil
    end
  end

  describe "assign_state/2" do
    test "assigns a state to a saga", context do
      saga = create_saga(5, "example_saga")
      {:ok, _} = StorageAdapter.initialize_saga(saga)

      new_state = %{step: "completed"}
      {:ok, updated_saga} = StorageAdapter.assign_state(saga, new_state)
      assert updated_saga.states == new_state

      {:ok, result} = Redix.command(context[:conn], ["GET", saga.unique_identifier])
      assert :erlang.binary_to_term(result) == updated_saga
    end
  end

  describe "assign_context/2" do
    test "assigns a context to a saga", context do
      saga = create_saga(7, "example_saga")
      {:ok, _} = StorageAdapter.initialize_saga(saga)

      new_context = %{user: "tester"}
      {:ok, updated_saga} = StorageAdapter.assign_context(saga, new_context)
      assert updated_saga.context == new_context

      {:ok, result} = Redix.command(context[:conn], ["GET", saga.unique_identifier])
      assert :erlang.binary_to_term(result) == updated_saga
    end
  end
end
