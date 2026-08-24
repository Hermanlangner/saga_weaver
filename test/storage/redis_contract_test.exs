defmodule SagaWeaver.Storage.RedisContractTest do
  use ExUnit.Case, async: false
  use SagaWeaver.StorageContract

  alias SagaWeaver.Storage.Redis

  setup_all do
    {:ok, connection} = Redix.start_link("redis://localhost:6379")
    %{connection: connection}
  end

  setup context do
    namespace = "saga_weaver_contract:#{System.unique_integer([:positive, :monotonic])}"

    on_exit(fn ->
      {:ok, keys} = Redix.command(context.connection, ["KEYS", "#{namespace}:*"])

      if keys != [] do
        Redix.command(context.connection, ["DEL" | keys])
      end
    end)

    %{
      namespace: namespace,
      storage:
        {Redis,
         connection: context.connection, namespace: namespace, max_retries: 50, retry_backoff: 1}
    }
  end

  defp storage(context), do: context.storage

  test "reads records written by SagaWeaver 0.2", context do
    legacy = %SagaWeaver.SagaSchema{
      uuid: "legacy-redis",
      saga_name: "LegacySaga",
      states: %{placed: true},
      context: %{customer_id: 42},
      marked_as_completed: true
    }

    redis_key = "#{context.namespace}:#{legacy.uuid}"

    assert {:ok, "OK"} =
             Redix.command(context.connection, ["SET", redis_key, :erlang.term_to_binary(legacy)])

    assert {:ok,
            %SagaWeaver.Instance{
              key: "legacy-redis",
              saga: "LegacySaga",
              status: :completed,
              state: %{"placed" => true},
              context: %{"customer_id" => 42}
            }} = SagaWeaver.Storage.fetch(storage(context), legacy.uuid)
  end

  test "returns an error for a malformed record", context do
    redis_key = "#{context.namespace}:malformed"

    assert {:ok, "OK"} = Redix.command(context.connection, ["SET", redis_key, "invalid"])

    assert {:error, {:invalid_record, %ArgumentError{}}} =
             SagaWeaver.Storage.fetch(storage(context), "malformed")
  end
end
