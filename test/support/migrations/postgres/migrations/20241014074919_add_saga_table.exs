defmodule SagaWeaver.Test.Repo.Migrations.AddSagaTable do
  use Ecto.Migration

  def change do
    create table(:sagaweaver_sagas) do
      add(:key, :string, null: false)
      add(:saga, :string, null: false)
      add(:state, :map, default: %{}, null: false)
      add(:context, :map, default: %{}, null: false)
      add(:status, :string, default: "active", null: false)
      add(:lock_version, :integer, default: 1, null: false)

      timestamps()
    end

    create(unique_index(:sagaweaver_sagas, [:key]))
  end
end
