defmodule SagaWeaver.IntegrationTests.FanOutFanInTest do
  use ExUnit.Case
  alias SagaWeaver.IntegrationTests.FanOutFanInTest.FanOutMessage
  alias SagaWeaver.IntegrationTests.FanOutFanInTest.FanInMessage

  defmodule FanOutMessage do
    defstruct [:id, :name]
  end

  defmodule FanInMessage do
    defstruct [:id, :fanout_id]
  end

  defmodule FanOutSaga do
    alias SagaWeaver.IntegrationTests.FanOutFanInTest.FanOutMessage
    alias SagaWeaver.IntegrationTests.FanOutFanInTest.FanInMessage

    alias SagaWeaver.SagaSchema

    def started_by do
      [FanOutMessage]
    end

    def entity_name do
      __MODULE__
    end

    def identity_key_mapping do
      %{
        FanOutMessage => fn message -> %{id: message.id, name: "test"} end,
        FanInMessage => fn message -> %{id: message.fanout_id} end
      }
    end

    def handle_message(%SagaSchema{} = instance, %FanOutMessage{} = _message) do
      fan_in_ids =
        1..100
        |> Enum.reduce(%{}, fn id, acc ->
          Map.put(acc, id, false)
        end)

      {:ok,
       instance
       |> SagaSchema.assign_state(fan_in_ids)}
    end

    def handle_message(%SagaSchema{} = instance, %FanInMessage{} = message) do
      instance = instance |> SagaSchema.assign_state(message.id, true)

      if ready_to_complete?(instance) do
        {:ok, instance |> SagaSchema.mark_as_completed()}
      else
        {:ok, instance}
      end
    end

    defp ready_to_complete?(instance) do
      Map.values(instance.states)
      |> Enum.all?(fn value -> value end)
    end
  end

  setup _context do
    start_supervised(SagaWeaver)

    :ok
  end

  test "Synchronous Fan out and Fan in completes saga" do
    fan_out_message = %FanOutMessage{id: 1, name: "test"}

    {:ok, _fan_out_saga} = SagaWeaver.execute_saga(FanOutSaga, fan_out_message)

    fan_in_messages =
      1..100
      |> Enum.map(fn id -> %FanInMessage{id: id, fanout_id: 1} end)

    Enum.each(fan_in_messages, fn message ->
      {:ok, _fan_in_saga} = SagaWeaver.execute_saga(FanOutSaga, message)
    end)

    fan_out_saga = SagaWeaver.retrieve_saga(FanOutSaga, fan_out_message)

    assert fan_out_saga == nil
  end

  test "Asynchronous Fan out and Fan in completes saga" do
    fan_out_message = %FanOutMessage{id: 1, name: "test"}

    fan_in_messages =
      1..100
      |> Enum.map(fn id -> %FanInMessage{id: id, fanout_id: 1} end)

    {:ok, _fan_out_saga} = SagaWeaver.execute_saga(FanOutSaga, fan_out_message)

    Task.async_stream(
      fan_in_messages,
      fn message ->
        SagaWeaver.execute_saga(FanOutSaga, message)
      end,
      max_concurrency: 100
    )
    |> Enum.to_list()

    fan_out_saga = SagaWeaver.retrieve_saga(FanOutSaga, fan_out_message)

    assert fan_out_saga == nil
  end
end
