defmodule SagaWeaver.SagaTest do
  use ExUnit.Case, async: true

  alias SagaWeaver.Instance

  defmodule NewSaga do
    use SagaWeaver.Saga

    @impl true
    def route(%{id: id}), do: {:start, "order:#{id}"}

    @impl true
    def handle(instance, _message) do
      {:ok, Instance.put_state(instance, :handled, true)}
    end
  end

  test "sagas expose route and handle callbacks" do
    instance = Instance.new(NewSaga, "order:1")

    assert NewSaga.route(%{id: 1}) == {:start, "order:1"}
    assert {:ok, %Instance{state: %{"handled" => true}}} = NewSaga.handle(instance, %{id: 1})
  end
end
