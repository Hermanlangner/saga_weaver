defmodule SagaWeaver.Consumer do
  @moduledoc false
  use GenStage

  alias SagaWeaver.Orchestrator

  @spec start_link(any()) :: {:ok, pid()}
  def start_link(event) do
    # Note: this function must return the format of `{:ok, pid}` and like
    # all children started by a Supervisor, the process must be linked
    # back to the supervisor (if you use `Task.start_link/1` then both
    # these requirements are met automatically)

    Task.start_link(fn ->
      handle_event(event)
    end)
  end

  @impl true
  def init({:ok, name}) do
    {:consumer, name,
     subscribe_to: [
       {SagaWeaver.Producer, max_demand: 1}
     ]}
  end

  defp handle_event({saga, message, from}) do
    result = Orchestrator.execute_saga(saga, message)
    GenStage.reply(from, result)
  end

  @impl true
  def handle_events(events, _from, name) do
    IO.puts("Consumer #{name} handling events: #{inspect(events)}")

    Enum.each(events, fn {saga, message, from} ->
      result = Orchestrator.execute_saga(saga, message)
      GenStage.reply(from, result)
    end)

    {:noreply, [], name}
  end
end
