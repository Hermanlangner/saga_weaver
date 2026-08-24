defmodule Sample.SimpleSagaTest do
  use Sample.DataCase, async: true

  alias SagaWeaver.Instance

  test "starts and completes the sample saga" do
    start_message = %StartSagaMessage{id: 1, name: "Start"}
    close_message = %CloseSagaMessage{external_id: 1, fanout_id: 1}

    assert {:ok, %Instance{state: %{"start_handled" => true}}} =
             Sample.Sagas.handle(SimpleSaga, start_message)

    assert {:ok, %Instance{status: :completed}} =
             Sample.Sagas.handle(SimpleSaga, close_message)

    assert {:ok, %Instance{status: :completed}} =
             Sample.Sagas.fetch(SimpleSaga, "simple:1")

    assert {:ignored, :completed} = Sample.Sagas.handle(SimpleSaga, start_message)
  end
end
