defmodule SagaWeaver.Storage.Postgres do
  @moduledoc """
  Stores saga instances in an application-owned Ecto repository.

  This adapter uses the existing `sagaweaver_sagas` table and reads records
  created by SagaWeaver 0.2 without a data migration.
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
    case repo(opts).get_by(Record, uuid: key) do
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
    case repo(opts).get_by(Record, uuid: key) do
      nil -> {:error, :not_found}
      %Record{marked_as_completed: true} -> {:error, :completed}
      record -> update_record(opts, record, changes, attempt)
    end
  end

  defp update_record(opts, record, changes, attempt) do
    result =
      record
      |> Record.changeset(merge_changes(record, changes))
      |> repo(opts).update(stale_error_field: :lock_version)

    resolve_commit(result, opts, record.uuid, changes, attempt)
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
    if Keyword.has_key?(changeset.errors, :uuid) do
      fetch(opts, key)
    else
      {:error, changeset}
    end
  end

  defp merge_changes(record, changes) do
    attrs = %{
      states: Map.merge(record.states || %{}, Map.get(changes, :state, %{})),
      context: Map.merge(record.context || %{}, Map.get(changes, :context, %{}))
    }

    case Map.get(changes, :status) do
      :completed -> Map.put(attrs, :marked_as_completed, true)
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
      uuid: instance.key,
      saga_name: instance.saga,
      states: instance.state,
      context: instance.context,
      marked_as_completed: instance.status == :completed
    }
  end

  defp to_instance(%Record{} = record), do: Instance.from_legacy(record)
  defp repo(opts), do: Keyword.fetch!(opts, :repo)
end
