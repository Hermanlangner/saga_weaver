defmodule Quickstart.OrderPlaced do
  defstruct [:order_id]
end

defmodule Quickstart.PaymentCaptured do
  defstruct [:order_id]
end

defmodule Quickstart.OrderSaga do
  use SagaWeaver.Saga

  alias SagaWeaver.Instance

  @impl true
  def route(%Quickstart.OrderPlaced{order_id: id}), do: {:start, "order:#{id}"}
  def route(%Quickstart.PaymentCaptured{order_id: id}), do: {:continue, "order:#{id}"}

  @impl true
  def handle(instance, %Quickstart.OrderPlaced{}) do
    {:ok, Instance.put_state(instance, :placed, true)}
  end

  def handle(instance, %Quickstart.PaymentCaptured{}) do
    {:complete, Instance.put_state(instance, :paid, true)}
  end
end

{:ok, storage} = SagaWeaver.Storage.Memory.start_link([])
options = [storage: {SagaWeaver.Storage.Memory, name: storage}]

placed = struct(Quickstart.OrderPlaced, order_id: 123)
paid = struct(Quickstart.PaymentCaptured, order_id: 123)

{:ok, started} = SagaWeaver.handle(Quickstart.OrderSaga, placed, options)
{:ok, completed} = SagaWeaver.handle(Quickstart.OrderSaga, paid, options)

IO.inspect(started, label: "Started")
IO.inspect(completed, label: "Completed")
