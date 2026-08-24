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

  test "rejects keys that cannot be normalized safely" do
    instance = Instance.new(TestSaga, "order:123")

    assert_raise ArgumentError, fn -> Instance.put_state(instance, 123, true) end
  end
end
