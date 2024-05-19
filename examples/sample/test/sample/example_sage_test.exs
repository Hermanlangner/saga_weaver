defmodule SagaExample.ExampleSagaTest do
  use ExUnit.Case

  alias SagaExample.ExampleSaga
  alias SagaWeaver.{TestEvent1, TestEvent2, SagaOrchestrator}

  test "run saga with TestEvent1" do
    event = %TestEvent1{external_id: 1, name: "Test Event 1"}
    {:ok, _result} = SagaOrchestrator.execute_saga(ExampleSaga, event)
  end

  test "run saga with TestEvent2" do
    event = %TestEvent2{id: 1, name: "Test Event 2"}
    {:ok, "Saga completed"} = SagaOrchestrator.execute_saga(ExampleSaga, event)
  end
end
