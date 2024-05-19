defmodule SagaWeaver.Saga do
  def entity_name(), do: __MODULE__

  def started_by(), do: [TestEvent1]

  def identity_key_mapping() do
    %{
      TestEvent1 => &%{id: &1.external_id},
      TestEvent2 => &%{id: &1.id}
    }
  end

  @spec handle_event(any(), any()) :: {:error, <<_::160>>}
  def handle_event(_entity, _event), do: {:error, "Event not recognized"}
end
