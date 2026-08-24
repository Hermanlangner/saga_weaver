defmodule Sample.SimpleSagaTest do
  use Sample.DataCase, async: true

  alias SagaWeaver.SagaSchema

  test "starts and completes the sample saga" do
    start_message = %StartSagaMessage{id: 1, name: "Start"}
    close_message = %CloseSagaMessage{external_id: 1, fanout_id: 1}

    assert {:ok, %SagaSchema{states: %{"start_handled" => true}}} =
             SagaWeaver.execute_saga(SimpleSaga, start_message)

    assert {:ok, %SagaSchema{marked_as_completed: true}} =
             SagaWeaver.execute_saga(SimpleSaga, close_message)

    assert {:ok, :not_found} = SagaWeaver.retrieve_saga(SimpleSaga, start_message)
  end
end
