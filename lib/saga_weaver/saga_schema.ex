defmodule SagaWeaver.SagaSchema do
  @moduledoc """
  The persisted schema returned by the deprecated SagaWeaver 0.2 API.

  New code receives `%SagaWeaver.Instance{}` instead. This module remains
  loadable so existing PostgreSQL rows and serialized Redis terms can be read
  during migration.
  """
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

  @type t() :: %__MODULE__{}

  @doc "Builds a changeset for the deprecated persisted saga schema."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(saga, attrs) do
    saga
    |> cast(attrs, [
      :id,
      :uuid,
      :saga_name,
      :states,
      :context,
      :marked_as_completed,
      :lock_version
    ])
    |> validate_required([
      :uuid,
      :saga_name
    ])
    |> unique_constraint(:uuid)
    |> optimistic_lock(:lock_version)
  end
end
