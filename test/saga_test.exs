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

  defmodule LegacyMessage do
    defstruct [:id]
  end

  defmodule LegacySaga do
    use SagaWeaver.Saga,
      started_by: [LegacyMessage],
      identity_key_mapping: %{LegacyMessage => &%{id: &1.id}}
  end

  test "new sagas expose route and handle callbacks" do
    instance = Instance.new(NewSaga, "order:1")

    assert NewSaga.__saga_weaver_api__() == :v2
    assert NewSaga.route(%{id: 1}) == {:start, "order:1"}
    assert {:ok, %Instance{state: %{"handled" => true}}} = NewSaga.handle(instance, %{id: 1})
  end

  test "legacy DSL remains available" do
    message = %LegacyMessage{id: 1}

    assert LegacySaga.__saga_weaver_api__() == :v1
    assert LegacySaga.started_by() == [LegacyMessage]
    assert LegacySaga.identity_key_mapping()[LegacyMessage].(message) == %{id: 1}
    assert LegacySaga.route(message) == :ignore
  end
end
