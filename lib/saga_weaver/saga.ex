defmodule SagaWeaver.SagaBehaviour do
  @callback saga_name() :: atom()
  @callback started_by() :: [module()]
  @callback how_to_find_saga() :: %{module() => (term() -> map())}
  @callback handle_message(SagaWeaver.SagaSchema.t(), any()) ::
              {:ok, SagaWeaver.SagaSchema.t()} | {:error, any()}
end

defmodule SagaWeaver.Saga do
  def saga_name(), do: __MODULE__

  def started_by(), do: [TestMessage1]

  def how_to_find_saga() do
    %{
      TestMessage1 => &%{id: &1.external_id},
      TestMessage2 => &%{id: &1.id}
    }
  end

  @spec handle_message(any(), any()) :: {:error, <<_::160>>}
  def handle_message(_entity, _message), do: {:error, "Message not recognized"}
end
