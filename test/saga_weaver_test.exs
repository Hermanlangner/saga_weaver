defmodule SagaWeaverTest do
  use ExUnit.Case
  doctest SagaWeaver

  test "greets the world" do
    assert SagaWeaver.hello() == :world
  end
end
