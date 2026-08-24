defmodule SagaWeaver.InstanceTest do
  use ExUnit.Case, async: true

  alias SagaWeaver.Instance

  test "tracks normalized state and context changes without persistence" do
    instance =
      TestSaga
      |> Instance.new("order:123")
      |> Instance.put_state(:placed, true)
      |> Instance.merge_state(%{"paid" => true})
      |> Instance.put_context(:customer_id, 42)

    assert instance.state == %{"paid" => true, "placed" => true}
    assert instance.context == %{"customer_id" => 42}

    assert Instance.changes(instance) == %{
             state: %{"paid" => true, "placed" => true},
             context: %{"customer_id" => 42},
             status: nil
           }
  end

  test "completion is retained as a pending status change" do
    instance = TestSaga |> Instance.new("order:123") |> Instance.complete()

    assert instance.status == :completed
    assert instance.changes.status == :completed
  end

  test "clear_changes preserves values" do
    instance =
      TestSaga
      |> Instance.new("order:123")
      |> Instance.put_state(:placed, true)
      |> Instance.clear_changes()

    assert instance.state == %{"placed" => true}
    assert instance.changes == %{state: %{}, context: %{}, status: nil}
  end

  test "legacy records become normalized instances" do
    legacy = %{
      uuid: "legacy:123",
      saga_name: "LegacySaga",
      states: %{placed: true},
      context: %{customer_id: 42},
      marked_as_completed: true,
      lock_version: 3,
      inserted_at: ~N[2026-01-01 00:00:00],
      updated_at: ~N[2026-01-02 00:00:00]
    }

    assert %Instance{
             key: "legacy:123",
             saga: "LegacySaga",
             status: :completed,
             state: %{"placed" => true},
             context: %{"customer_id" => 42},
             version: 3
           } = Instance.from_legacy(legacy)
  end

  test "rejects keys that cannot be normalized safely" do
    instance = Instance.new(TestSaga, "order:123")

    assert_raise ArgumentError, fn -> Instance.put_state(instance, 123, true) end
  end
end
