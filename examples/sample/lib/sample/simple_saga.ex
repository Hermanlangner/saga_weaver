defmodule StartSagaMessage do
  defstruct [:id, :name]
end

defmodule CloseSagaMessage do
  defstruct [:external_id, :fanout_id]
end

defmodule SimpleSaga do
  use SagaWeaver.Saga,
    started_by: [StartSagaMessage],
    identity_key_mapping: %{
      StartSagaMessage => fn message -> %{id: message.id} end,
      CloseSagaMessage => fn message -> %{id: message.external_id} end
    }

    alias SagaWeaver.SagaSchema

   def handle_message(%SagaSchema{} = instance, %StartSagaMessage{} = message) do
    case instance.states["start_handled"] do
        true -> IO.puts "Start Message already handled for id: #{message.id}"
        _nil_or_false ->
          IO.puts "Starting Saga for id: #{message.id}"
          #Do initial setup
    end

    {:ok,
     instance
     |> assign_state("start_handled", true)}
  end

  def handle_message(%SagaSchema{} = instance, %CloseSagaMessage{} = message) do
    instance = instance |> assign_state("close_handled", true)

    if ready_to_complete?(instance) do
      IO.puts "All conditions for closure have been met, closing"
      {:ok, instance |> mark_as_completed()}
    else
      {:ok, instance}
    end
  end

  defp ready_to_complete?(instance) do
    instance.states["start_handled"] && instance.states["close_handled"]
  end
end
