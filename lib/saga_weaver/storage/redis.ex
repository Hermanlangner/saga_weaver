defmodule SagaWeaver.Storage.Redis do
  @moduledoc """
  Stores saga instances through an application-owned Redix connection.

  Values written by SagaWeaver 0.2 are decoded into `%SagaWeaver.Instance{}`
  without rewriting their keys or payloads during reads.
  """

  @behaviour SagaWeaver.Storage

  alias SagaWeaver.{Instance, SagaSchema}

  @commit_script """
  local current = redis.call('GET', KEYS[1])
  if not current then
    return -1
  end
  if current ~= ARGV[1] then
    return 0
  end
  redis.call('SET', KEYS[1], ARGV[2])
  return 1
  """

  @impl SagaWeaver.Storage
  def validate_options(opts) do
    with {:ok, connection} <- required(opts, :connection),
         {:ok, namespace} <- required(opts, :namespace),
         true <- is_binary(namespace) and namespace != "" do
      {:ok, [connection: connection, namespace: namespace]}
    else
      false -> {:error, {:invalid_option, :namespace}}
      {:error, _reason} = error -> error
    end
  end

  @impl SagaWeaver.Storage
  def fetch(opts, key) do
    with {:ok, binary} <- fetch_binary(opts, key) do
      decode(binary)
    end
  end

  @impl SagaWeaver.Storage
  def insert_new(opts, %Instance{} = instance) do
    command = ["SET", namespaced_key(opts, instance.key), encode(instance), "NX"]

    case Redix.command(connection(opts), command) do
      {:ok, "OK"} -> {:ok, Instance.clear_changes(instance)}
      {:ok, nil} -> fetch(opts, instance.key)
      {:error, reason} -> {:error, reason}
    end
  end

  @impl SagaWeaver.Storage
  def commit(opts, %Instance{} = instance, changes) do
    commit_with_retry(opts, instance.key, changes, 0)
  end

  defp commit_with_retry(opts, key, changes, attempt) do
    max_retries = Keyword.fetch!(opts, :max_retries)

    if attempt > max_retries do
      {:error, :conflict}
    else
      redis_key = namespaced_key(opts, key)

      with {:ok, binary} <- fetch_binary(opts, key),
           {:ok, current} <- decode(binary) do
        commit_current(opts, redis_key, binary, current, changes, attempt)
      end
    end
  end

  defp commit_current(
         _opts,
         _redis_key,
         _binary,
         %Instance{status: :completed},
         _changes,
         _attempt
       ),
       do: {:error, :completed}

  defp commit_current(opts, redis_key, binary, current, changes, attempt) do
    updated = current |> Instance.apply_changes(changes) |> Instance.clear_changes()
    compare_and_set(opts, redis_key, binary, updated, changes, attempt)
  end

  defp compare_and_set(opts, redis_key, binary, updated, changes, attempt) do
    result =
      Redix.command(connection(opts), [
        "EVAL",
        @commit_script,
        1,
        redis_key,
        binary,
        encode(updated)
      ])

    resolve_commit(result, opts, updated.key, changes, updated, attempt)
  end

  defp resolve_commit({:ok, 0}, opts, key, changes, _updated, attempt) do
    backoff(opts, attempt)
    commit_with_retry(opts, key, changes, attempt + 1)
  end

  defp resolve_commit({:ok, 1}, _opts, _key, _changes, updated, _attempt),
    do: {:ok, updated}

  defp resolve_commit({:ok, -1}, _opts, _key, _changes, _updated, _attempt),
    do: {:error, :not_found}

  defp resolve_commit({:error, reason}, _opts, _key, _changes, _updated, _attempt),
    do: {:error, reason}

  defp resolve_commit(unexpected, _opts, _key, _changes, _updated, _attempt),
    do: {:error, {:unexpected_redis_response, unexpected}}

  defp fetch_binary(opts, key) do
    case Redix.command(connection(opts), ["GET", namespaced_key(opts, key)]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, binary} -> {:ok, binary}
      {:error, reason} -> {:error, reason}
    end
  end

  # Stored terms need legacy decoding; safe mode forbids creating atoms.
  # sobelow_skip ["Misc.BinToTerm"]
  defp decode(binary) do
    case :erlang.binary_to_term(binary, [:safe]) do
      %Instance{} = instance -> {:ok, Instance.clear_changes(instance)}
      %SagaSchema{} = legacy -> {:ok, Instance.from_legacy(legacy)}
      value -> {:error, {:unsupported_record, record_type(value)}}
    end
  rescue
    error in ArgumentError -> {:error, {:invalid_record, error}}
  end

  defp encode(%Instance{} = instance),
    do: :erlang.term_to_binary(Instance.clear_changes(instance))

  defp record_type(%{__struct__: module}) when is_atom(module), do: {:struct, module}
  defp record_type(value) when is_map(value), do: :map
  defp record_type(value) when is_list(value), do: :list
  defp record_type(value) when is_tuple(value), do: :tuple
  defp record_type(value) when is_binary(value), do: :binary
  defp record_type(_value), do: :other

  defp namespaced_key(opts, key), do: "#{Keyword.fetch!(opts, :namespace)}:#{key}"
  defp connection(opts), do: Keyword.fetch!(opts, :connection)

  defp required(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, nil} -> {:error, {:missing_option, key}}
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_option, key}}
    end
  end

  defp backoff(opts, attempt) do
    Process.sleep(Keyword.fetch!(opts, :retry_backoff) * attempt)
  end
end
