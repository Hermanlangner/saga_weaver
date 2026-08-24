defmodule Mix.Tasks.SagaWeaver.InstallTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.SagaWeaver.Install

  setup do
    Mix.Task.reenable("saga_weaver.install")
    :ok
  end

  test "prints PostgreSQL migration and facade setup" do
    output =
      capture_io(fn ->
        Install.run(["--storage", "postgres", "--dry-run"])
      end)

    assert output =~ "Would create priv/repo/migrations/"
    assert output =~ "defmodule SagaWeaver.Sagas"
    assert output =~ "SagaWeaver.Storage.Postgres"
    assert output =~ "SagaWeaver.Repo"
  end

  test "prints host-owned Redis setup" do
    output =
      capture_io(fn ->
        Install.run(["--storage", "redis"])
      end)

    assert output =~ "{Redix, name: SagaWeaver.SagaRedis"
    assert output =~ "SagaWeaver.Storage.Redis"
    assert output =~ "connection: SagaWeaver.SagaRedis"
  end

  test "generates the compatible PostgreSQL table" do
    migration =
      Install.migration("MyApp.Repo.Migrations.CreateSagaWeaverSagas")

    assert migration =~ "create table(:sagaweaver_sagas)"
    assert migration =~ "add :lock_version, :integer, default: 1"
    assert migration =~ "create unique_index(:sagaweaver_sagas, [:uuid])"
  end

  test "rejects invalid module names" do
    assert_raise Mix.Error, ~r/--repo must be an Elixir alias/, fn ->
      Install.run([
        "--storage",
        "postgres",
        "--repo",
        "MyApp.Repo\nSystem.cmd(\"sh\", [])",
        "--dry-run"
      ])
    end
  end

  test "rejects migration paths outside the project" do
    assert_raise Mix.Error, ~r/--migrations-path must stay within/, fn ->
      Install.run([
        "--storage",
        "postgres",
        "--migrations-path",
        "../outside",
        "--dry-run"
      ])
    end
  end
end
