defmodule SagaWeaver.Storage.PostgresContractTest do
  use SagaWeaver.DataCase, async: false
  use SagaWeaver.StorageContract

  alias SagaWeaver.{Instance, SagaSchema, Storage}
  alias SagaWeaver.Storage.Postgres
  alias SagaWeaver.Test.Repo

  setup do
    %{
      storage: {Postgres, repo: SagaWeaver.Test.Repo, max_retries: 50, retry_backoff: 1}
    }
  end

  defp storage(context), do: context.storage

  test "reads records written by the legacy Postgres adapter", context do
    legacy = %SagaSchema{
      uuid: "legacy-postgres:#{System.unique_integer([:positive])}",
      saga_name: "LegacySaga",
      states: %{placed: true},
      context: %{customer_id: 42},
      marked_as_completed: true
    }

    assert {:ok, _legacy} =
             legacy
             |> SagaSchema.changeset(%{})
             |> Repo.insert()

    assert {:ok,
            %Instance{
              key: key,
              saga: "LegacySaga",
              status: :completed,
              state: %{"placed" => true},
              context: %{"customer_id" => 42}
            }} = Storage.fetch(storage(context), legacy.uuid)

    assert key == legacy.uuid
  end
end
