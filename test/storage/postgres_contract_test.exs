defmodule SagaWeaver.Storage.PostgresContractTest do
  use SagaWeaver.DataCase, async: false
  use SagaWeaver.StorageContract

  alias SagaWeaver.Storage.Postgres

  setup do
    %{
      storage: {Postgres, repo: SagaWeaver.Test.Repo, max_retries: 50, retry_backoff: 1}
    }
  end

  defp storage(context), do: context.storage
end
