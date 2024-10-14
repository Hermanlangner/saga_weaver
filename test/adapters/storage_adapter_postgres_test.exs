defmodule SagaWeaver.Adapters.StorageAdapterPostgresTest do
  @moduledoc false
  use SagaWeaver.DataCase
  alias SagaWeaver.Adapters.StorageAdapter
  alias SagaWeaver.SagaSchema

  setup_all do
    Application.put_env(:saga_weaver, SagaWeaver,
      storage_adapter: SagaWeaver.Adapters.PostgresAdapter,
      repo: SagaWeaver.Test.Repo
    )

    :ok
  end

  defp create_saga(id, name) do
    %SagaSchema{
      uuid: "#{name}:#{id}",
      saga_name: name,
      states: %{},
      context: %{},
      marked_as_completed: false
    }
  end

  describe "initialize_saga/1" do
    test "Multiple initializes all return the latest instance instead of initializing" do
      saga = create_saga(1, "example_saga")

      result_list =
        Task.async_stream(
          1..50,
          fn _index ->
            {:ok, result} = StorageAdapter.initialize_saga(saga)
            result
          end,
          max_concurrency: 50
        )
        |> Enum.map(fn {_response_code, result} -> result end)

      sage_to_check = List.first(result_list)

      assert Enum.all?(result_list, fn created_saga ->
               created_saga === sage_to_check
             end)

      assert true == StorageAdapter.saga_exists?(saga.uuid)
    end
  end

  describe "get_saga/1" do
    test "returns a saga if it exists" do
      created_saga = create_saga(2, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(created_saga)

      assert {:ok, ^saga} = StorageAdapter.get_saga(saga.uuid)
    end

    test "returns not_found if saga does not exist", _context do
      assert {:ok, :not_found} == StorageAdapter.get_saga("nonexistent_saga")
    end
  end

  describe "saga_exists?/1" do
    test "returns a saga if it exists" do
      created_saga = create_saga(22, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(created_saga)

      assert true == StorageAdapter.saga_exists?(saga.uuid)
    end

    test "returns false if saga does not exist", _context do
      assert false == StorageAdapter.saga_exists?("nonexistent_saga")
    end
  end

  describe "mark_as_completed/1" do
    test "marks a saga as completed" do
      created_saga = create_saga(3, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(created_saga)

      {:ok, updated_saga} = StorageAdapter.mark_as_completed(saga)
      assert updated_saga.marked_as_completed

      {:ok, result} = StorageAdapter.get_saga(saga.uuid)
      assert result == updated_saga
    end

    test "marks a saga as completed during high concurrency" do
      created_saga = create_saga(33, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(created_saga)

      result_list =
        Task.async_stream(
          1..50,
          fn _index ->
            {:ok, result} = StorageAdapter.mark_as_completed(saga)
            result
          end,
          max_concurrency: 50
        )
        |> Enum.map(fn {_response_code, result} -> result end)

      {:ok, updated_saga} = StorageAdapter.get_saga(saga.uuid)

      assert Enum.all?(result_list, fn created_saga ->
               created_saga.marked_as_completed == updated_saga.marked_as_completed
             end)
    end
  end

  describe "complete_saga/1" do
    test "completes (deletes) a saga" do
      created_saga = create_saga(4, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(created_saga)

      assert :ok = StorageAdapter.complete_saga(saga)

      assert false == StorageAdapter.saga_exists?(saga.uuid)
    end

    test "completes (deletes) a saga during high concurrency" do
      created_saga = create_saga(44, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(created_saga)

      assert :ok = StorageAdapter.complete_saga(saga)

      result_list =
        Task.async_stream(
          1..50,
          fn _index ->
            StorageAdapter.complete_saga(saga)
          end,
          max_concurrency: 50
        )
        |> Enum.map(fn {_response_code, result} -> result end)

      assert Enum.all?(result_list, fn created_saga -> created_saga == :ok end)
      assert false == StorageAdapter.saga_exists?(saga.uuid)
    end
  end

  describe "assign_state/2" do
    test "assigns a state to a saga" do
      saga_struct = create_saga(53, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(saga_struct)

      new_state = %{"step" => "completed"}
      {:ok, updated_saga} = StorageAdapter.assign_state(saga, new_state)
      assert updated_saga.states == new_state

      {:ok, result} = StorageAdapter.get_saga(saga.uuid)
      assert result == updated_saga
    end

    # This is actually a bad test, need to simulate fan in and fan out test
    test "assigns a state to a saga during high concurrency" do
      created_saga = create_saga(663, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(created_saga)
      new_state = %{"step" => "completed"}

      result_list =
        Task.async_stream(
          1..50,
          fn _index ->
            {:ok, result} = StorageAdapter.assign_state(saga, new_state)
            result
          end,
          max_concurrency: 50
        )
        |> Enum.map(fn {_response_code, result} -> result end)

      {:ok, updated_saga} = StorageAdapter.get_saga(saga.uuid)

      assert Enum.all?(result_list, fn created_saga ->
               created_saga.states == updated_saga.states &&
                 created_saga.uuid == updated_saga.uuid
             end)
    end
  end

  describe "assign_context/2" do
    test "assigns a context to a saga" do
      created_saga = create_saga(7, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(created_saga)

      new_context = %{"user" => "tester"}
      {:ok, updated_saga} = StorageAdapter.assign_context(saga, new_context)
      assert updated_saga.context == new_context

      {:ok, result} = StorageAdapter.get_saga(saga.uuid)

      assert result.context == updated_saga.context &&
               result.uuid == updated_saga.uuid
    end

    test "assigns a context to a saga during high concurrency" do
      created_saga = create_saga(77, "example_saga")
      {:ok, saga} = StorageAdapter.initialize_saga(created_saga)
      new_context = %{user: "tester"}

      result_list =
        Task.async_stream(
          1..50,
          fn _index ->
            {:ok, result} = StorageAdapter.assign_context(saga, new_context)
            result
          end,
          max_concurrency: 50
        )
        |> Enum.map(fn {_response_code, result} -> result end)

      {:ok, updated_saga} = StorageAdapter.get_saga(saga.uuid)

      assert Enum.all?(result_list, fn created_saga ->
               created_saga.context == updated_saga.context &&
                 created_saga.uuid == updated_saga.uuid
             end)
    end
  end
end
