defmodule SagaWeaver.ConsumerSupervisor do
  use ConsumerSupervisor

  def start_link(arg) do
    ConsumerSupervisor.start_link(__MODULE__, arg)
  end

  def init(_arg) do
    # Note: By default the restart for a child is set to :permanent
    # which is not supported in ConsumerSupervisor. You need to explicitly
    # set the :restart option either to :temporary or :transient.
    children = [
      %{
        id: SagaWeaver.Consumer,
        start: {SagaWeaver.Consumer, :start_link, []},
        restart: :transient
      }
    ]

    opts = [
      strategy: :one_for_one,
      subscribe_to: [{SagaWeaver.Producer, min_demand: 25, max_demand: 50}]
    ]

    ConsumerSupervisor.init(children, opts)
  end
end
