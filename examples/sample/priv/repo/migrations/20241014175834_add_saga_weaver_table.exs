defmodule Sample.Repo.Migrations.AddSagaWeaverTable do
  use Ecto.Migration

  def change do
    create table(:sagaweaver_sagas) do
      add(:uuid, :string)
      add(:saga_name, :string)
      add(:states, :map, default: %{})
      add(:context, :map, default: %{})
      add(:marked_as_completed, :boolean, default: false)
      add(:lock_version, :integer, default: 1)

      timestamps()
    end

    create(index(:sagaweaver_sagas, [:uuid], unique: true))
  end
end
