defmodule ExSagaTest do
  use ExUnit.Case
  doctest ExSaga

  test "greets the world" do
    assert ExSaga.hello() == :world
  end
end
