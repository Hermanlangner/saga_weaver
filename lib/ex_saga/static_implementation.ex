defmodule ExSaga.StaticImplementation do
  @behaviour ExSaga.SagaBehavior

  alias ExSaga.{RedisAdapter, SagaEntity, TestEvent1, TestEvent2}

  @impl true
  def entity_name(), do: __MODULE__

  @impl true
  def instance_name(event) do
    entity_name()
    |> to_string()
    |> Kernel.<>(":")
    |> Kernel.<>(get_identity_key(event))
  end

  @impl true
  def started_by(), do: [TestEvent1]

  @impl true
  @spec run_saga(any()) :: any()
  def run_saga(event) do
    case find_saga_instance(event) do
      nil -> start_saga(event)
      instance -> handle_event(instance, event)
    end
  end

  @impl true
  @spec start_saga(any()) :: any()
  def start_saga(event) do
    if event.__struct__ in started_by() do
      event
      |> create_instance()
      |> handle_event(event)
    else
      {:error, "Event not supported"}
    end
  end

  @impl true
  @spec mark_as_completed(ExSaga.SagaEntity.t()) :: any()
  def mark_as_completed(_entity) do
    # Implementation here
  end

  @impl true
  @spec handle_event(ExSaga.SagaEntity.t(), any()) :: any()
  def handle_event(entity, %TestEvent1{} = event) do
    RedisAdapter.write_record("test_event_1", event)
  end

  @impl true
  def handle_event(entity, %TestEvent2{} = event) do
    RedisAdapter.write_record("test_event_2", event)
  end

  @impl true
  def handle_event(_entity, _event), do: {:error, "Event not recognized"}

  @impl true
  @spec create_instance(any()) :: any()
  def create_instance(event) do
    instance_name = instance_name(event)
    RedisAdapter.write_record(instance_name, event)
    instance_name
  end

  @impl true
  @spec find_saga_instance(any()) :: any()
  def find_saga_instance(event), do: RedisAdapter.read_record(instance_name(event))

  defp identity_key_mapping(),
    do: %{
      TestEvent1 => &%{id: &1.external_id},
      TestEvent2 => &%{id: &1.id}
    }

  def get_identity_key(event) do
    entity_name = to_string(entity_name())
    identity_keys = identity_key_mapping()[event.__struct__].(event)

    identity_keys
    |> Enum.reduce("#{entity_name}:", fn {key, value}, acc ->
      acc <> "#{to_string(key)}:#{to_string(value)},"
    end)
    |> md5_hash()
  end

  defp md5_hash(input_string) do
    :crypto.hash(:sha256, input_string)
    |> Base.encode16(case: :lower)
  end
end
