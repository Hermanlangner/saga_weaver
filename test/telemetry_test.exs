defmodule SagaWeaver.TelemetryTest do
  use ExUnit.Case, async: true

  alias SagaWeaver.Instance
  alias SagaWeaver.Storage.Memory

  @events [
    [:saga_weaver, :handle, :start],
    [:saga_weaver, :handle, :stop],
    [:saga_weaver, :handle, :exception],
    [:saga_weaver, :storage, :fetch, :start],
    [:saga_weaver, :storage, :fetch, :stop],
    [:saga_weaver, :storage, :insert_new, :start],
    [:saga_weaver, :storage, :insert_new, :stop],
    [:saga_weaver, :storage, :commit, :start],
    [:saga_weaver, :storage, :commit, :stop],
    [:saga_weaver, :completion],
    [:saga_weaver, :ignored]
  ]

  defmodule TelemetrySaga do
    use SagaWeaver.Saga

    @impl true
    def route(%{type: :ignore}), do: :ignore
    def route(%{id: id}), do: {:start, "telemetry:#{id}"}

    @impl true
    def handle(instance, %{type: :complete}), do: {:complete, Instance.complete(instance)}
    def handle(instance, _message), do: {:ok, Instance.put_state(instance, :handled, true)}
  end

  defmodule RaisingSaga do
    use SagaWeaver.Saga

    @impl true
    def route(_message), do: {:start, "raising"}

    @impl true
    def handle(_instance, _message), do: raise("callback failed")
  end

  setup do
    pid = start_supervised!(Memory)
    handler_id = {__MODULE__, self()}

    :ok =
      :telemetry.attach_many(
        handler_id,
        @events,
        fn event, measurements, metadata, test_pid ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    %{storage: {Memory, name: pid}}
  end

  test "emits handle and storage spans", %{storage: storage} do
    assert {:ok, _instance} =
             SagaWeaver.handle(TelemetrySaga, %{id: 1, type: :start}, storage: storage)

    assert_receive {:telemetry, [:saga_weaver, :handle, :start], %{system_time: _}, metadata}
    assert metadata.saga == TelemetrySaga

    assert_receive {:telemetry, [:saga_weaver, :storage, :fetch, :start], _, _}
    assert_receive {:telemetry, [:saga_weaver, :storage, :insert_new, :stop], %{duration: _}, _}
    assert_receive {:telemetry, [:saga_weaver, :storage, :commit, :stop], %{duration: _}, _}
    assert_receive {:telemetry, [:saga_weaver, :handle, :stop], %{duration: _}, %{result: :ok}}
  end

  test "emits completion and ignored events", %{storage: storage} do
    assert {:ok, _instance} =
             SagaWeaver.handle(TelemetrySaga, %{id: 2, type: :complete}, storage: storage)

    assert_receive {:telemetry, [:saga_weaver, :completion], _, %{key: "telemetry:2"}}

    assert {:ignored, :unrouted} =
             SagaWeaver.handle(TelemetrySaga, %{type: :ignore}, storage: storage)

    assert_receive {:telemetry, [:saga_weaver, :ignored], _, %{reason: :unrouted}}
  end

  test "emits exception spans and returns a structured callback error", %{storage: storage} do
    assert {:error,
            %SagaWeaver.Error{kind: :callback, reason: %RuntimeError{message: "callback failed"}}} =
             SagaWeaver.handle(RaisingSaga, %{}, storage: storage)

    assert_receive {:telemetry, [:saga_weaver, :handle, :exception], %{duration: _}, metadata}
    assert metadata.kind == :error
    assert %RuntimeError{message: "callback failed"} = metadata.reason
  end
end
