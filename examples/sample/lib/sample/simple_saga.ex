defmodule StartSagaMessage do
  defstruct [:id, :name]
end

defmodule CloseSagaMessage do
  defstruct [:external_id, :fanout_id]
end

defmodule SimpleSaga do
  use SagaWeaver.Saga

  alias SagaWeaver.Instance

  @impl true
  def route(%StartSagaMessage{id: id}), do: {:start, "simple:#{id}"}
  def route(%CloseSagaMessage{external_id: id}), do: {:continue, "simple:#{id}"}
  def route(_message), do: :ignore

  @impl true
  def handle(%Instance{} = instance, %StartSagaMessage{} = message) do
    case instance.state["start_handled"] do
      true ->
        IO.puts("Start Message already handled for id: #{message.id}")

      _nil_or_false ->
        IO.puts("Starting Saga for id: #{message.id}")
        # Do initial setup
    end

    {:ok, Instance.put_state(instance, "start_handled", true)}
  end

  def handle(%Instance{} = instance, %CloseSagaMessage{}) do
    instance = Instance.put_state(instance, "close_handled", true)

    if ready_to_complete?(instance) do
      IO.puts("All conditions for closure have been met, closing")
      {:complete, instance}
    else
      {:ok, instance}
    end
  end

  defp ready_to_complete?(instance) do
    instance.state["start_handled"] && instance.state["close_handled"]
  end
end
