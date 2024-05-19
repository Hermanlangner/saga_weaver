defmodule InitialDesign do
  alias ExSaga.RedisAdapter

  defmodule Event do
    @callback name() :: atom()
    @callback content_type() :: atom()
  end

  defmodule TestEvent1 do
    defstruct [:external_id, :name]

    @type t :: %__MODULE__{external_id: integer(), name: String.t()}
    @behaviour Event
    def name, do: :test_event_1
    def content_type, do: TestEvent1
  end

  defmodule TestEvent2 do
    defstruct [:id, :name]

    @type t :: %__MODULE__{id: integer(), name: String.t()}

    @behaviour Event
    def name, do: :test_event_2
    def content_type, do: TestEvent2
  end

  defmodule SagaEntity do
    defstruct [:unique_identifier, :saga_name, :states, :context, :marked_as_completed]

    @type t :: %__MODULE__{
            unique_identifier: String.t(),
            saga_name: atom(),
            states: list(),
            context: map(),
            marked_as_completed: boolean()
          }
  end

  defmodule StaticImplementation do
    @moduledoc """
    This module handles the lifecycle of saga instances and event processing.
    """

    def entity_name(), do: __MODULE__

    def instance_name(event) do
      entity_name()
      |> to_string()
      |> Kernel.<>(":")
      |> Kernel.<>(get_identity_key(event))
    end

    def started_by(), do: [TestEvent1]

    def run_saga(event) do
      case find_saga_instance(event) do
        nil -> start_saga(event)
        instance -> handle_event(instance, event)
      end
    end

    def start_saga(event) do
      if event.__struct__ in started_by() do
        event
        |> create_instance()
        |> handle_event(event)
      else
        {:error, "Event not supported"}
      end
    end

    def mark_as_completed(entity) do
    end

    defp completed?(_entity, _event), do: false

    def create_instance(event) do
      instance_name = instance_name(event)
      RedisAdapter.write_record(instance_name, event)
      instance_name
    end

    def find_saga_instance(event), do: RedisAdapter.read_record(instance_name(event))

    def handle_event(entity, %TestEvent1{} = event) do
      RedisAdapter.write_record("test_event_1", event)
    end

    def handle_event(entity, %TestEvent2{} = event) do
      RedisAdapter.write_record("test_event_2", event)
    end

    def handle_event(_entity, _event), do: {:error, "Event not recognized"}

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
end
