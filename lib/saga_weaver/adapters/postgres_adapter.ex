defmodule SagaWeaver.Adapters.PostgresAdapter do
  @moduledoc false
  @behaviour SagaWeaver.Adapters.StorageAdapter

  alias SagaWeaver.SagaSchema
  import Ecto.Query

  @impl SagaSchema
  def initialize_saga(%SagaSchema{} = saga) do
    case get_saga(saga.uuid) do
      {:ok, :not_found} ->
        try_create_saga(saga)

      {:ok, existing_saga} = ok ->
        ok
    end
  end

  @spec try_create_saga(SagaSchema.t()) :: {:ok, SagaSchema.t()} | {:error, Ecto.Changeset.t()}
  def try_create_saga(saga) do
    saga
    |> SagaSchema.changeset(%{})
    |> repo().insert()
    |> case do
      {:ok, saga} = ok ->
        ok

      {:error, changeset} ->
        handle_insert_failure(changeset)
    end
  end

  defp handle_insert_failure(changeset) do
    unique_collision =
      {"has already been taken",
       [constraint: :unique, constraint_name: "sagaweaver_sagas_uuid_index"]}

    case Keyword.get(changeset.errors, :uuid) do
      unique_collision ->
        get_saga(changeset.data.uuid)

      _errors ->
        raise "Unable to create saga: #{inspect(changeset)}"
    end
  end

  @impl SagaSchema
  @spec saga_exists?(String.t()) :: boolean()
  def saga_exists?(uuid) do
    repo().exists?(from(s in SagaSchema, where: s.uuid == ^uuid))
  end

  @impl SagaSchema
  @spec get_saga(String.t()) :: {:ok, SagaSchema.t()} | {:ok, :not_found}
  def get_saga(uuid) do
    case repo().get_by(SagaSchema, uuid: uuid) do
      nil -> {:ok, :not_found}
      saga -> {:ok, saga}
    end
  end

  @impl SagaSchema
  @spec mark_as_completed(SagaSchema.t()) :: {:ok, SagaSchema.t()}
  def mark_as_completed(%SagaSchema{} = saga) do
    update_saga(saga, %{marked_as_completed: true})
    |> case do
      {:ok, updated_saga} = ok ->
        ok

      {:error, :stale_entry} ->
        {:ok, %{saga | marked_as_completed: true}}
    end
  end

  @impl SagaSchema
  @spec complete_saga(SagaSchema.t()) :: :ok
  def complete_saga(%SagaSchema{} = saga) do
    case repo().delete(saga,
           conflict_target: :lock_version,
           stale_error_field: :lock_version,
           returning: true
         ) do
      {:ok, _saga} -> :ok
      {:error, _changeset} -> :ok
    end
  end

  @impl SagaSchema
  @spec assign_state(SagaSchema.t(), map()) :: {:ok, SagaSchema.t()}
  def assign_state(%SagaSchema{} = saga, state) do
    updated_states = Map.merge(saga.states || %{}, state)
    update_saga(saga, %{states: updated_states})

    update_fn = fn saga ->
      updated_states = Map.merge(saga.states || %{}, state)
      try_update_saga(saga, %{states: updated_states})
    end

    try_update_until_not_stale(saga.uuid, update_fn)
  end

  @impl SagaSchema
  @spec assign_context(SagaSchema.t(), map()) :: {:ok, SagaSchema.t()}
  def assign_context(%SagaSchema{} = saga, context) do
    update_fn = fn saga ->
      updated_context = Map.merge(saga.context || %{}, context)
      try_update_saga(saga, %{context: updated_context})
    end

    try_update_until_not_stale(saga.uuid, update_fn)
  end

  defp update_saga(%SagaSchema{} = saga, attrs) do
    saga
    |> SagaSchema.changeset(attrs)
    |> repo().update()
    |> handle_db_result()
  rescue
    Ecto.StaleEntryError ->
      {:error, :stale_entry}
  end

  defp try_update_until_not_stale(uuid, update_fn, delay \\ 0) do
    get_saga(uuid)
    |> case do
      {:ok, saga} = ok ->
        update_fn.(saga)
        |> case do
          {:ok, saga} = ok ->
            ok

          {:ok, :stale_entry} ->
            Process.sleep(delay)
            try_update_until_not_stale(uuid, update_fn, delay + 1)
        end

      {:ok, :not_found} = not_found ->
        not_found
    end
  end

  def try_update_saga(saga, attrs) do
    saga
    |> SagaSchema.changeset(attrs)
    |> repo().update(
      conflict_target: :lock_version,
      stale_error_field: :lock_version,
      returning: true
    )
    |> case do
      {:ok, saga} = ok ->
        ok

      {:error, changeset} ->
        handle_insert_failure(changeset)
    end
  end

  defp handle_update_failure(changeset) do
    case Keyword.get(changeset.errors, :lock_version) do
      ["is stale"] ->
        {:ok, :stale_entry}

      _errors ->
        raise "Unable to update saga: #{inspect(changeset)}"
    end
  end

  defp handle_db_result({:ok, saga}), do: {:ok, saga}
  defp handle_db_result({:error, changeset}), do: {:error, changeset}

  defp repo() do
    Application.get_env(:saga_weaver, :repo)
  end
end
