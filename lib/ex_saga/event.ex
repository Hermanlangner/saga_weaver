defmodule ExSaga.Event do
  @callback name() :: atom()
  @callback content_type() :: atom()
end

defmodule ExSaga.TestEvent1 do
  @behaviour ExSaga.Event

  defstruct [:external_id, :name]

  @type t :: %__MODULE__{external_id: integer(), name: String.t()}

  def name, do: :test_event_1
  def content_type, do: TestEvent1
end

defmodule ExSaga.TestEvent2 do
  @behaviour ExSaga.Event

  defstruct [:id, :name]

  @type t :: %__MODULE__{id: integer(), name: String.t()}

  def name, do: :test_event_2
  def content_type, do: TestEvent2
end
