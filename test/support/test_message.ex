defmodule SagaWeaver.Test.TestMessage do
  defstruct [:id, :uuid, :atom_key]

  @type t :: %__MODULE__{id: integer(), uuid: String.t(), atom_key: atom()}

  def name, do: __MODULE__
  def content_type, do: __MODULE__
end
