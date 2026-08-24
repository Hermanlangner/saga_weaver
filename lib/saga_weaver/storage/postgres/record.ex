defmodule SagaWeaver.Storage.Postgres.Record do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  schema "sagaweaver_sagas" do
    field(:uuid, :string)
    field(:saga_name, :string)
    field(:states, :map, default: %{})
    field(:context, :map, default: %{})
    field(:marked_as_completed, :boolean, default: false)
    field(:lock_version, :integer, default: 1)
    timestamps()
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [:uuid, :saga_name, :states, :context, :marked_as_completed])
    |> validate_required([:uuid, :saga_name])
    |> unique_constraint(:uuid)
    |> optimistic_lock(:lock_version)
  end
end
