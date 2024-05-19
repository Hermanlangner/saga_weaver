defmodule SagaWeaver.SagaBehaviour do
  @callback saga_name() :: atom()
  @callback started_by() :: [module()]
  @callback how_to_find_saga() :: %{module() => (term() -> map())}
  @callback handle_event(SagaWeaver.SagaSchema.t(), any()) ::
              {:ok, SagaWeaver.SagaSchema.t()} | {:error, any()}
end

defmodule SagaWeaver.Saga do
  def saga_name(), do: __MODULE__

  def started_by(), do: [TestEvent1]

  def how_to_find_saga() do
    %{
      TestEvent1 => &%{id: &1.external_id},
      TestEvent2 => &%{id: &1.id}
    }
  end

  @spec handle_event(any(), any()) :: {:error, <<_::160>>}
  def handle_event(_entity, _event), do: {:error, "Event not recognized"}
end
