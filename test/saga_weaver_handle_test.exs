defmodule SagaWeaver.HandleTest do
  use ExUnit.Case, async: true

  alias SagaWeaver.{Error, Instance}
  alias SagaWeaver.Storage.Memory

  defmodule OrderSaga do
    use SagaWeaver.Saga

    @impl true
    def route(%{type: :placed, id: id}), do: {:start, "order:#{id}"}
    def route(%{type: :paid, id: id}), do: {:continue, "order:#{id}"}
    def route(%{type: :complete, id: id}), do: {:continue, "order:#{id}"}
    def route(_message), do: :ignore

    @impl true
    def handle(instance, %{type: :placed}) do
      {:ok, Instance.put_state(instance, :placed, true)}
    end

    def handle(instance, %{type: :paid}) do
      {:ok, Instance.put_state(instance, :paid, true)}
    end

    def handle(instance, %{type: :complete}) do
      {:complete, Instance.put_state(instance, :closed, true)}
    end
  end

  defmodule BrokenSaga do
    use SagaWeaver.Saga

    @impl true
    def route(_message), do: {:start, "broken"}

    @impl true
    def handle(_instance, _message), do: {:error, :broken}
  end

  defmodule OtherSaga do
    use SagaWeaver.Saga

    @impl true
    def route(%{id: id}), do: {:start, "order:#{id}"}

    @impl true
    def handle(instance, _message), do: {:ok, Instance.put_state(instance, :other, true)}
  end

  defmodule IdentityChangingSaga do
    use SagaWeaver.Saga

    @impl true
    def route(_message), do: {:start, "identity-changing"}

    @impl true
    def handle(instance, _message) do
      {:ok, %{instance | key: "another-key", saga: "AnotherSaga"}}
    end
  end

  defmodule InvalidRouteSaga do
    use SagaWeaver.Saga

    @impl true
    def route(_message), do: {:start, :not_a_string}
  end

  defmodule InvalidHandleSaga do
    use SagaWeaver.Saga

    @impl true
    def route(_message), do: {:start, "invalid-handle"}

    @impl true
    def handle(_instance, _message), do: :invalid
  end

  setup do
    pid = start_supervised!(Memory)
    %{storage: {Memory, name: pid}}
  end

  test "starts, continues, and fetches an instance", %{storage: storage} do
    assert {:ok, %Instance{state: %{"placed" => true}}} =
             SagaWeaver.handle(OrderSaga, %{type: :placed, id: 1}, storage: storage)

    assert {:ok, %Instance{state: %{"paid" => true, "placed" => true}}} =
             SagaWeaver.handle(OrderSaga, %{type: :paid, id: 1}, storage: storage)

    assert {:ok, %Instance{key: "order:1"}} =
             SagaWeaver.fetch(OrderSaga, "order:1", storage: storage)
  end

  test "distinguishes unrouted and not-started messages", %{storage: storage} do
    assert {:ignored, :unrouted} =
             SagaWeaver.handle(OrderSaga, %{type: :unknown, id: 1}, storage: storage)

    assert {:ignored, :not_started} =
             SagaWeaver.handle(OrderSaga, %{type: :paid, id: 1}, storage: storage)
  end

  test "retains completion and ignores replayed messages", %{storage: storage} do
    assert {:ok, _instance} =
             SagaWeaver.handle(OrderSaga, %{type: :placed, id: 1}, storage: storage)

    assert {:ok, %Instance{status: :completed, state: %{"closed" => true}}} =
             SagaWeaver.handle(OrderSaga, %{type: :complete, id: 1}, storage: storage)

    assert {:ignored, :completed} =
             SagaWeaver.handle(OrderSaga, %{type: :placed, id: 1}, storage: storage)

    assert {:ok, %Instance{status: :completed}} =
             SagaWeaver.fetch(OrderSaga, "order:1", storage: storage)
  end

  test "wraps expected callback failures", %{storage: storage} do
    assert {:error, %Error{kind: :callback, reason: :broken}} =
             SagaWeaver.handle(BrokenSaga, %{}, storage: storage)
  end

  test "rejects a route key owned by another saga", %{storage: storage} do
    assert {:ok, %Instance{}} =
             SagaWeaver.handle(OrderSaga, %{type: :placed, id: 1}, storage: storage)

    assert {:error,
            %Error{
              kind: :routing,
              reason: {:saga_mismatch, "Elixir.SagaWeaver.HandleTest.OrderSaga"}
            }} = SagaWeaver.handle(OtherSaga, %{id: 1}, storage: storage)

    assert {:error, %Error{kind: :routing, reason: {:saga_mismatch, _persisted}}} =
             SagaWeaver.fetch(OtherSaga, "order:1", storage: storage)
  end

  test "rejects a handler that changes persisted identity", %{storage: storage} do
    assert {:error,
            %Error{
              kind: :callback,
              reason: {:invalid_instance_identity, %{expected: expected, returned: returned}}
            }} = SagaWeaver.handle(IdentityChangingSaga, %{}, storage: storage)

    assert expected == %{
             key: "identity-changing",
             saga: "Elixir.SagaWeaver.HandleTest.IdentityChangingSaga"
           }

    assert returned == %{key: "another-key", saga: "AnotherSaga"}

    assert {:error, :not_found} =
             SagaWeaver.fetch(IdentityChangingSaga, "another-key", storage: storage)

    assert {:ok, %Instance{key: "identity-changing", state: %{}}} =
             SagaWeaver.fetch(IdentityChangingSaga, "identity-changing", storage: storage)
  end

  test "wraps invalid route and handler results", %{storage: storage} do
    assert {:error, %Error{kind: :routing, reason: {:invalid_route, {:start, :not_a_string}}}} =
             SagaWeaver.handle(InvalidRouteSaga, %{}, storage: storage)

    assert {:error, %Error{kind: :callback, reason: {:invalid_return, :invalid}}} =
             SagaWeaver.handle(InvalidHandleSaga, %{}, storage: storage)
  end

  test "returns not found through the public fetch API", %{storage: storage} do
    assert {:error, :not_found} = SagaWeaver.fetch(OrderSaga, "order:missing", storage: storage)
  end

  test "returns a structured configuration error" do
    assert {:error, %Error{kind: :config}} = SagaWeaver.handle(OrderSaga, %{type: :placed, id: 1})
  end
end
