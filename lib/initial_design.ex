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
    def name, do: TestEvent2
    def content_type, do: TestEvent2
  end

  defmodule StaticImplementation do
    def entity_name() do
      __MODULE__
    end

    def identity_key_mapping() do
      %{
        TestEvent1 => fn event -> %{id: event.external_id} end,
        TestEvent2 => fn event -> %{id: event.id} end
      }
    end

    def handle_event(%TestEvent1{} = event) do
      RedisAdapter.write_record("test_event_1", event)
    end

    def get_identity_key(event) do
      entity_name = entity_name() |> to_string()
      identity_keys = identity_key_mapping()[event.__struct__].(event)

      identity_keys
      |> Enum.reduce("#{entity_name}:", fn {key, value}, acc ->
        acc = acc <> "#{to_string(key)}:#{to_string(value)},"
        acc
      end)
      |> md5_hash()
    end

    def md5_hash(input_string) do
      :crypto.hash(:md5, input_string)
      |> Base.encode16(case: :lower)
    end
  end
end
