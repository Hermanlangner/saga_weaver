defmodule SagaWeaverTest do
  use ExUnit.Case
  doctest SagaWeaver

  setup context do
    on_exit(fn ->
      Redix.command(context[:conn], ["FLUSHALL"])
    end)

    :ok
  end
end
