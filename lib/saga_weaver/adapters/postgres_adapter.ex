defmodule SagaWeaver.Adapters.PostgresAdapter do
  @moduledoc false
  @behaviour SagaWeaver.Adapters.StorageAdapter

  alias SagaWeaver.SagaSchema
  import Ecto.Query

  @impl SagaSchema
  def initialize_saga(%SagaSchema{} = saga) do
    case get_saga(saga.uuid) do
      {:ok, :not_found} ->
        saga
        |> SagaSchema.changeset(%{})
        |> repo().insert()
        |> handle_db_result()

      {:ok, existing_saga} ->
        {:ok, existing_saga}
    end
  end

  @impl SagaSchema
  def saga_exists?(uuid) do
    repo().exists?(from(s in SagaSchema, where: s.uuid == ^uuid))
  end

  @impl SagaSchema
  def get_saga(uuid) do
    case repo().get(SagaSchema, uuid) do
      nil -> {:ok, :not_found}
      saga -> {:ok, saga}
    end
  end

  @impl SagaSchema
  def mark_as_completed(%SagaSchema{} = saga) do
    update_saga(saga, %{marked_as_completed: true})
  end

  @impl SagaSchema
  def complete_saga(%SagaSchema{} = saga) do
    case repo().delete(saga) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl SagaSchema
  def assign_state(%SagaSchema{} = saga, state) do
    updated_states = Map.merge(saga.states || %{}, state)
    update_saga(saga, %{states: updated_states})
  end

  @impl SagaSchema
  def assign_context(%SagaSchema{} = saga, context) do
    updated_context = Map.merge(saga.context || %{}, context)
    update_saga(saga, %{context: updated_context})
  end

  # Helper Functions

  defp update_saga(%SagaSchema{} = saga, attrs) do
    saga
    |> SagaSchema.changeset(attrs)
    |> repo().update()
    |> handle_db_result()
  rescue
    Ecto.StaleEntryError ->
      {:error, :stale_entry}
  end

  defp handle_db_result({:ok, saga}), do: {:ok, saga}
  defp handle_db_result({:error, changeset}), do: {:error, changeset}

  defp repo() do
    Application.get_env(:saga_weaver, :repo)
  end
end
