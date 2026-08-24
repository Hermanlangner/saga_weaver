defmodule SagaWeaver.IntegrationTests.FanOutFanInPostgresTest do
  use SagaWeaver.DataCase
  alias SagaWeaver.IntegrationTests.FanOutFanInPostgresTest.FanInMessage
  alias SagaWeaver.IntegrationTests.FanOutFanInPostgresTest.FanOutMessage

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

    alias SagaWeaver.IntegrationTests.FanOutFanInPostgresTest.FanInMessage
    alias SagaWeaver.IntegrationTests.FanOutFanInPostgresTest.FanOutMessage

    alias SagaWeaver.SagaSchema

    @impl true
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
    restore =
      SagaWeaver.TestEnv.put_env(:saga_weaver, SagaWeaver,
        storage_adapter: SagaWeaver.Adapters.PostgresAdapter,
        repo: SagaWeaver.Test.Repo
      )

    on_exit(restore)
    :ok
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

    results =
      Task.async_stream(
        fan_in_messages,
        fn message ->
          SagaWeaver.Orchestrator.execute_saga(FanOutSaga, message)
        end,
        max_concurrency: System.schedulers_online() * 2,
        timeout: 30_000
      )
      |> Enum.to_list()

    assert Enum.all?(results, &match?({:ok, {:ok, %SagaWeaver.SagaSchema{}}}, &1))

    fan_out_saga = SagaWeaver.Orchestrator.retrieve_saga(FanOutSaga, fan_out_message)

    assert fan_out_saga == {:ok, :not_found}
  end
end
