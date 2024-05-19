defmodule SagaWeaver.SagaEntity do
  defstruct [:unique_identifier, :saga_name, :states, :context, :marked_as_completed]

  @type t :: %__MODULE__{
          unique_identifier: String.t(),
          saga_name: atom(),
          states: map(),
          context: map(),
          marked_as_completed: boolean()
        }
end
