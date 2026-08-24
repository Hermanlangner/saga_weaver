defmodule SagaWeaver.TestingTest do
  use ExUnit.Case, async: true

  alias SagaWeaver.Storage.Memory

  test "builds direct API options for supervised memory storage" do
    storage = start_supervised!(Memory)

    assert [storage: {Memory, name: ^storage}] = SagaWeaver.Testing.options(storage)
  end

  test "preserves explicit overrides" do
    storage = start_supervised!(Memory)

    assert [storage: {Memory, name: :custom}, max_retries: 2] =
             SagaWeaver.Testing.options(storage,
               storage: {Memory, name: :custom},
               max_retries: 2
             )
  end
end
