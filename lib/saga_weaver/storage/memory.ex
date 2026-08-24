defmodule SagaWeaver.Storage.Memory do
  @moduledoc """
  A supervised in-memory storage implementation intended for tests and examples.

  Start it under a supervisor and pass its pid or registered name as the
  `:name` storage option.
  """

  use Agent

  @behaviour SagaWeaver.Storage

  alias SagaWeaver.Instance

  @doc """
  Starts an empty in-memory saga store.
  """
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name)

    if name do
      Agent.start_link(fn -> %{} end, name: name)
    else
      Agent.start_link(fn -> %{} end)
    end
  end

  @impl SagaWeaver.Storage
  def validate_options(opts) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} -> {:ok, [name: name]}
      :error -> {:error, {:missing_option, :name}}
    end
  end

  @impl SagaWeaver.Storage
  def fetch(opts, key) do
    opts
    |> Keyword.fetch!(:name)
    |> Agent.get(fn instances ->
      case Map.fetch(instances, key) do
        {:ok, instance} -> {:ok, instance}
        :error -> {:error, :not_found}
      end
    end)
  end

  @impl SagaWeaver.Storage
  def insert_new(opts, %Instance{} = instance) do
    opts
    |> Keyword.fetch!(:name)
    |> Agent.get_and_update(fn instances ->
      persisted = Instance.clear_changes(instance)

      case Map.fetch(instances, instance.key) do
        {:ok, existing} -> {{:ok, existing}, instances}
        :error -> {{:ok, persisted}, Map.put(instances, instance.key, persisted)}
      end
    end)
  end

  @impl SagaWeaver.Storage
  def commit(opts, %Instance{} = instance, changes) do
    opts
    |> Keyword.fetch!(:name)
    |> Agent.get_and_update(fn instances ->
      case Map.fetch(instances, instance.key) do
        {:ok, %Instance{status: :completed}} ->
          {{:error, :completed}, instances}

        {:ok, current} ->
          updated = current |> Instance.apply_changes(changes) |> Instance.clear_changes()
          {{:ok, updated}, Map.put(instances, instance.key, updated)}

        :error ->
          {{:error, :not_found}, instances}
      end
    end)
  end
end
