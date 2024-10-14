defmodule SagaWeaver.Test.Repo.Migrations.AddSagaTable do
  use Ecto.Migration

  def change do
    create table(:sagaweaver_sagas) do
      add(:uuid, :uuid)
      add(:name, :string)
      add(:status, :string)

      timestamps()
    end

    create(index(:sagaweaver_sagas, [:uuid], unique: true))
  end
end
