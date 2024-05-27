#defmodule SagaExample.ExampleSaga do
#  use SagaWeaver.Saga
#
#  def entity_name(), do: __MODULE__
#
#  def started_by(), do: [SagaWeaver.TestEvent1]
#
#  def identity_key_mapping() do
#    %{
#      SagaWeaver.TestEvent1 => &%{id: &1.external_id},
#      SagaWeaver.TestEvent2 => &%{id: &1.id}
#    }
#  end
#
#  @spec handle_event(SagaWeaver.SagaEntity.t(), any()) :: {:ok, SagaWeaver.SagaEntity.t()} | {:error, String.t()}
#  def handle_event(saga, %SagaWeaver.TestEvent1{} = event) do
#    # Handle TestEvent1 and update saga state
#    {:ok, saga}
#  end
#
#  def handle_event(saga, %SagaWeaver.TestEvent2{} = event) do
#    # Handle TestEvent2 and mark saga as completed
#    updated_saga = %{saga | marked_as_completed: true}
#    {:ok, updated_saga}
#  end
#
#  def handle_event(_, _), do: {:error, "Event not recognized"}
#end
