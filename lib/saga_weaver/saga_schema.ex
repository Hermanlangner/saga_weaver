defmodule SagaWeaver.SagaSchema do
  use Ecto.Schema

  @primary_key {:unique_identifier, :string, autogenerate: false}
  schema "sagaweaver_sagas" do
    field(:saga_name, :string)
    field(:states, :map, default: %{})
    field(:context, :map, default: %{})
    field(:marked_as_completed, :boolean, default: false)

    timestamps()
  end
end
