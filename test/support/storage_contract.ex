defmodule SagaWeaver.StorageContract do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      alias SagaWeaver.{Instance, Storage}

      test "fetch returns not found", context do
        assert {:error, :not_found} = Storage.fetch(storage(context), contract_key("missing"))
      end

      test "insert_new is idempotent", context do
        storage = storage(context)
        instance = Instance.new("ContractSaga", contract_key("insert"))

        assert {:ok, first} = Storage.insert_new(storage, instance)
        assert {:ok, second} = Storage.insert_new(storage, instance)
        assert first == second
      end

      test "commit merges normalized state and context changes", context do
        storage = storage(context)
        instance = insert_contract_instance(storage, "changes")

        changed =
          instance
          |> Instance.put_state(:placed, true)
          |> Instance.put_context(:customer_id, 42)

        assert {:ok, persisted} =
                 Storage.commit(storage, instance, Instance.changes(changed))

        assert persisted.state == %{"placed" => true}
        assert persisted.context == %{"customer_id" => 42}
        assert persisted.changes == %{state: %{}, context: %{}, status: nil}
      end

      test "completion is retained", context do
        storage = storage(context)
        instance = insert_contract_instance(storage, "complete")
        completed = Instance.complete(instance)

        assert {:ok, %Instance{status: :completed}} =
                 Storage.commit(storage, instance, Instance.changes(completed))

        assert {:ok, %Instance{status: :completed}} = Storage.fetch(storage, instance.key)
      end

      test "completed instances reject stale transitions", context do
        storage = storage(context)
        instance = insert_contract_instance(storage, "completed-race")
        completed = Instance.complete(instance)

        assert {:ok, %Instance{status: :completed}} =
                 Storage.commit(storage, instance, Instance.changes(completed))

        stale = Instance.put_state(instance, :late, true)

        assert {:error, :completed} =
                 Storage.commit(storage, instance, Instance.changes(stale))

        assert {:ok, %Instance{status: :completed, state: state}} =
                 Storage.fetch(storage, instance.key)

        refute Map.has_key?(state, "late")
      end

      test "concurrent disjoint changes are preserved", context do
        storage = storage(context)
        instance = insert_contract_instance(storage, "concurrent")

        results =
          1..20
          |> Task.async_stream(
            fn index ->
              changed = Instance.put_state(instance, "step_#{index}", index)
              Storage.commit(storage, instance, Instance.changes(changed))
            end,
            max_concurrency: 20,
            timeout: 10_000
          )
          |> Enum.to_list()

        assert Enum.all?(results, &match?({:ok, {:ok, %Instance{}}}, &1))
        assert {:ok, persisted} = Storage.fetch(storage, instance.key)
        assert map_size(persisted.state) == 20

        for index <- 1..20 do
          assert persisted.state["step_#{index}"] == index
        end
      end

      defp insert_contract_instance(storage, label) do
        instance = Instance.new("ContractSaga", contract_key(label))
        {:ok, persisted} = Storage.insert_new(storage, instance)
        persisted
      end

      defp contract_key(label) do
        "#{inspect(__MODULE__)}:#{label}:#{System.unique_integer([:positive, :monotonic])}"
      end
    end
  end
end
