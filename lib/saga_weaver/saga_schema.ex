defmodule SagaWeaver.SagaSchema do
  @moduledoc false
  defstruct [:unique_identifier, :saga_name, :states, :context, :marked_as_completed]

  alias SagaWeaver.Adapters.StorageAdapter

  @type t :: %__MODULE__{
          unique_identifier: String.t(),
          saga_name: atom(),
          states: map(),
          context: map(),
          marked_as_completed: boolean()
        }

  def assign_state(instance, key, value) do
    assign_state(instance, %{key => value})
  end

  def assign_state(instance, state_map) do
    {:ok, instance} = StorageAdapter.assign_state(instance, state_map)
    instance
  end

  def assign_context(instance, key, value) do
    {:ok, instance} =
      StorageAdapter.assign_context(instance, Map.put(instance.context, key, value))

    instance
  end

  def mark_as_completed(instance) do
    {:ok, instance} = StorageAdapter.mark_as_completed(instance)
    instance
  end
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
