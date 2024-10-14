defmodule SagaWeaver.IntegrationTests.FanOutFanInRedisTest do
  use ExUnit.Case
  alias SagaWeaver.IntegrationTests.FanOutFanInRedisTest.FanInMessage
  alias SagaWeaver.IntegrationTests.FanOutFanInRedisTest.FanOutMessage

  defmodule FanOutMessage do
    defstruct [:id, :name]
  end

  defmodule FanInMessage do
    defstruct [:id, :fanout_id]
  end

  defmodule FanOutSaga do
    use SagaWeaver.Saga,
      started_by: [FanOutMessage],
      identity_key_mapping: %{
        FanOutMessage => fn message -> %{id: message.id} end,
        FanInMessage => fn message -> %{id: message.fanout_id} end
      }

    alias SagaWeaver.IntegrationTests.FanOutFanInRedisTest.FanInMessage
    alias SagaWeaver.IntegrationTests.FanOutFanInRedisTest.FanOutMessage

    alias SagaWeaver.SagaSchema

    def handle_message(%SagaSchema{} = instance, %FanOutMessage{} = _message) do
      fan_in_ids =
        1..100
        |> Enum.reduce(%{}, fn id, acc ->
          Map.put(acc, id, false)
        end)

      {:ok,
       instance
       |> assign_state(fan_in_ids)}
    end

    def handle_message(%SagaSchema{} = instance, %FanInMessage{} = message) do
      instance = instance |> assign_state(message.id, true)

      if ready_to_complete?(instance) do
        {:ok, instance |> mark_as_completed()}
      else
        {:ok, instance}
      end
    end

    defp ready_to_complete?(instance) do
      Map.values(instance.states)
      |> Enum.all?(fn value -> value end)
    end
  end

  setup_all do
    {:ok, conn} = Redix.start_link("redis://localhost:6379")
    Application.put_env(SagaWeaver, :storage_adapter, SagaWeaver.Adapters.RedisAdapter)

    on_exit(fn ->
      Redix.command(conn, ["FLUSHALL"])
    end)

    {:ok, conn: conn}
  end

  test "Synchronous Fan out and Fan in completes saga" do
    fan_out_message = %FanOutMessage{id: 1, name: "test"}

    {:ok, _fan_out_saga} = SagaWeaver.Orchestrator.execute_saga(FanOutSaga, fan_out_message)

    fan_in_messages =
      1..100
      |> Enum.map(fn id -> %FanInMessage{id: id, fanout_id: 1} end)

    Enum.each(fan_in_messages, fn message ->
      {:ok, _fan_in_saga} = SagaWeaver.Orchestrator.execute_saga(FanOutSaga, message)
    end)

    fan_out_saga = SagaWeaver.Orchestrator.retrieve_saga(FanOutSaga, fan_out_message)

    assert fan_out_saga == {:ok, :not_found}
  end

  test "Asynchronous Fan out and Fan in completes saga" do
    fan_out_message = %FanOutMessage{id: 1, name: "test"}

    fan_in_messages =
      1..100
      |> Enum.map(fn id -> %FanInMessage{id: id, fanout_id: 1} end)

    {:ok, _fan_out_saga} = SagaWeaver.Orchestrator.execute_saga(FanOutSaga, fan_out_message)

    Task.async_stream(
      fan_in_messages,
      fn message ->
        SagaWeaver.Orchestrator.execute_saga(FanOutSaga, message)
      end,
      max_concurrency: 100
    )
    |> Enum.to_list()

    fan_out_saga = SagaWeaver.Orchestrator.retrieve_saga(FanOutSaga, fan_out_message)

    assert fan_out_saga == {:ok, :not_found}
  end
end
