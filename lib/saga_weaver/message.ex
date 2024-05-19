defmodule SagaWeaver.Behaviours.Message do
  @callback name() :: atom()
  @callback content_type() :: atom()
end

# defmodule SagaWeaver.TestMessage1 do
#  @behaviour SagaWeaver.Message
#
#  defstruct [:external_id, :name]
#
#  @type t :: %__MODULE__{external_id: integer(), name: String.t()}
#
#  def name, do: :test_Message_1
#  def content_type, do: TestMessage1
# end
#
# defmodule SagaWeaver.TestMessage2 do
# @behaviour SagaWeaver.Message
#
# defstruct [:id, :name]
#
# @type t :: %__MODULE__{id: integer(), name: String.t()}
#
# def name, do: :test_Message_2
# def content_type, do: TestMessage2
# end
