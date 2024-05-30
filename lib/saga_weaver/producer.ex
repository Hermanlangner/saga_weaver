defmodule SagaWeaver.Producer do
  @moduledoc false
  use GenStage

  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def execute_saga(saga, message) do
    GenServer.call(__MODULE__, {:execute_saga, saga, message}, :infinity)
  end

  @impl true
  def init(:ok) do
    {:producer, {:queue.new(), 0}}
  end

  @impl true
  def handle_call({:execute_saga, saga, message}, from, {queue, demand}) do
    queue = :queue.in({saga, message, from}, queue)
    #  IO.puts("Producer received execute_saga call")
    dispatch_events(queue, demand)
  end

  @impl true
  def handle_demand(demand, {queue, _demand}) do
    #  IO.puts("Producer handling demand: #{demand}")
    dispatch_events(queue, demand)
  end

  defp dispatch_events(queue, demand) do
    {events, queue} = dequeue_events(queue, demand, [])
    #  IO.puts("Producer dispatching events: #{inspect(events)}")
    {:noreply, events, {queue, demand - length(events)}}
  end

  defp dequeue_events(queue, 0, acc), do: {Enum.reverse(acc), queue}

  defp dequeue_events(queue, demand, acc) do
    case :queue.out(queue) do
      {:empty, queue} -> {Enum.reverse(acc), queue}
      {{:value, event}, queue} -> dequeue_events(queue, demand - 1, [event | acc])
    end
  end
end
