defmodule SagaWeaver.Storage.MemoryContractTest do
  use ExUnit.Case, async: true
  use SagaWeaver.StorageContract

  alias SagaWeaver.Storage.Memory

  setup do
    pid = start_supervised!(Memory)
    %{storage: {Memory, name: pid, max_retries: 5, retry_backoff: 0}}
  end

  defp storage(context), do: context.storage
end
