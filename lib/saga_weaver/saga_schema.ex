defmodule SagaWeaver.SagaSchema do
  @moduledoc false
  defstruct [:unique_identifier, :saga_name, :states, :context, :marked_as_completed]

  @type t :: %__MODULE__{
          unique_identifier: String.t(),
          saga_name: atom(),
          states: map(),
          context: map(),
          marked_as_completed: boolean()
        }
end

# defmodule SagaWeaver.SagaSchema do
#  use Ecto.Schema
#
#  @primary_key {:unique_identifier, :string, autogenerate: false}
#  schema "sagas" do
#    field :saga_name, :string
#    field :states, :map, default: %{}
#    field :context, :map, default: %{}
#    field :marked_as_completed, :boolean, default: false
#
#    timestamps()
#  end
# end
