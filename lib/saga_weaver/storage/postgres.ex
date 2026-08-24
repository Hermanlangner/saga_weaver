defmodule SagaWeaver.Storage.Postgres do
  @moduledoc """
  Stores saga instances in an application-owned Ecto repository.
  """

  @behaviour SagaWeaver.Storage

  alias SagaWeaver.Instance
  alias SagaWeaver.Storage.Postgres.Record

  @impl SagaWeaver.Storage
  def validate_options(opts) do
    case Keyword.fetch(opts, :repo) do
      {:ok, repo} when is_atom(repo) -> {:ok, [repo: repo]}
      {:ok, value} -> {:error, {:invalid_option, :repo, value}}
      :error -> {:error, {:missing_option, :repo}}
    end
  end

  @impl SagaWeaver.Storage
  def fetch(opts, key) do
    case repo(opts).get_by(Record, key: key) do
      nil -> {:error, :not_found}
      record -> {:ok, to_instance(record)}
    end
  end

  @impl SagaWeaver.Storage
  def insert_new(opts, %Instance{} = instance) do
    instance
    |> to_record()
    |> Record.changeset(%{})
    |> repo(opts).insert()
    |> case do
      {:ok, record} -> {:ok, to_instance(record)}
      {:error, changeset} -> resolve_insert_conflict(opts, instance.key, changeset)
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
      fetch_and_commit(opts, key, changes, attempt)
    end
  end

  defp fetch_and_commit(opts, key, changes, attempt) do
    case repo(opts).get_by(Record, key: key) do
      nil -> {:error, :not_found}
      %Record{status: :completed} -> {:error, :completed}
      record -> update_record(opts, record, changes, attempt)
    end
  end

  defp update_record(opts, record, changes, attempt) do
    result =
      record
      |> Record.changeset(merge_changes(record, changes))
      |> repo(opts).update(stale_error_field: :lock_version)

    resolve_commit(result, opts, record.key, changes, attempt)
  end

  defp resolve_commit({:ok, updated}, _opts, _key, _changes, _attempt) do
    {:ok, to_instance(updated)}
  end

  defp resolve_commit({:error, changeset}, opts, key, changes, attempt) do
    if stale?(changeset) do
      backoff(opts, attempt)
      commit_with_retry(opts, key, changes, attempt + 1)
    else
      {:error, changeset}
    end
  end

  defp resolve_insert_conflict(opts, key, changeset) do
    if Keyword.has_key?(changeset.errors, :key) do
      fetch(opts, key)
    else
      {:error, changeset}
    end
  end

  defp merge_changes(record, changes) do
    attrs = %{
      state: Map.merge(record.state || %{}, Map.get(changes, :state, %{})),
      context: Map.merge(record.context || %{}, Map.get(changes, :context, %{}))
    }

    case Map.get(changes, :status) do
      :completed -> Map.put(attrs, :status, :completed)
      nil -> attrs
    end
  end

  defp stale?(changeset) do
    match?({"is stale", [stale: true]}, Keyword.get(changeset.errors, :lock_version))
  end

  defp backoff(opts, attempt) do
    Process.sleep(Keyword.fetch!(opts, :retry_backoff) * attempt)
  end

  defp to_record(%Instance{} = instance) do
    %Record{
      key: instance.key,
      saga: instance.saga,
      state: instance.state,
      context: instance.context,
      status: instance.status
    }
  end

  defp to_instance(%Record{} = record) do
    %Instance{
      key: record.key,
      saga: record.saga,
      status: record.status,
      state: record.state || %{},
      context: record.context || %{},
      version: record.lock_version,
      inserted_at: record.inserted_at,
      updated_at: record.updated_at
    }
  end

  defp repo(opts), do: Keyword.fetch!(opts, :repo)
end
