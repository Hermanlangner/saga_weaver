defmodule SagaWeaver.Storage.Postgres.Record do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  schema "sagaweaver_sagas" do
    field(:key, :string)
    field(:saga, :string)
    field(:state, :map, default: %{})
    field(:context, :map, default: %{})
    field(:status, Ecto.Enum, values: [:active, :completed], default: :active)
    field(:lock_version, :integer, default: 1)
    timestamps()
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [:key, :saga, :state, :context, :status])
    |> validate_required([:key, :saga, :status])
    |> unique_constraint(:key)
    |> optimistic_lock(:lock_version)
  end
end
