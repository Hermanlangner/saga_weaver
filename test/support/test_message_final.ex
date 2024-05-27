defmodule SagaWeaver.Test.TestMessageFinal do
  defstruct [:external_id, :external_uuid, :external_atom_key]

  @type t :: %__MODULE__{
          external_id: integer(),
          external_uuid: String.t(),
          external_atom_key: atom()
        }

  def name, do: __MODULE__
  def content_type, do: __MODULE__
end
