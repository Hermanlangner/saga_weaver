defmodule SagaWeaverTest do
  use ExUnit.Case
  doctest SagaWeaver

  setup_all do
    SagaWeaver.start_link([])

    :ok
  end

  setup context do
    on_exit(fn ->
      Redix.command(context[:conn], ["FLUSHALL"])
    end)

    :ok
  end
end
