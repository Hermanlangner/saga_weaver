defmodule SagaWeaver.Instance do
  @moduledoc """
  The adapter-neutral runtime representation of a saga instance.

  Instance helpers are pure. They update the in-memory value and record a
  change set that SagaWeaver commits after a handler succeeds. State and
  context keys are normalized to strings so all storage adapters expose the
  same values.
  """

  @type status :: :active | :completed
  @type changes :: %{
          state: %{optional(String.t()) => term()},
          context: %{optional(String.t()) => term()},
          status: status() | nil
        }

  @type t :: %__MODULE__{
          key: String.t(),
          saga: String.t(),
          status: status(),
          state: map(),
          context: map(),
          version: non_neg_integer() | nil,
          inserted_at: term(),
          updated_at: term(),
          changes: changes()
        }

  @enforce_keys [:key, :saga]
  defstruct key: nil,
            saga: nil,
            status: :active,
            state: %{},
            context: %{},
            version: nil,
            inserted_at: nil,
            updated_at: nil,
            changes: %{state: %{}, context: %{}, status: nil}

  @doc """
  Creates an active saga instance with no persisted changes.
  """
  @spec new(module() | String.t(), String.t()) :: t()
  def new(saga, key) when is_atom(saga) and is_binary(key) do
    %__MODULE__{saga: Atom.to_string(saga), key: key}
  end

  def new(saga, key) when is_binary(saga) and is_binary(key) do
    %__MODULE__{saga: saga, key: key}
  end

  @doc """
  Puts a value in the instance state and records it for the next commit.
  """
  @spec put_state(t(), String.t() | atom(), term()) :: t()
  def put_state(%__MODULE__{} = instance, key, value) do
    merge_state(instance, %{normalize_key(key) => value})
  end

  @doc """
  Merges values into the instance state and records them for the next commit.
  """
  @spec merge_state(t(), map()) :: t()
  def merge_state(%__MODULE__{} = instance, values) when is_map(values) do
    values = normalize_keys(values)

    %{
      instance
      | state: Map.merge(instance.state, values),
        changes: %{instance.changes | state: Map.merge(instance.changes.state, values)}
    }
  end

  @doc """
  Puts a value in the instance context and records it for the next commit.
  """
  @spec put_context(t(), String.t() | atom(), term()) :: t()
  def put_context(%__MODULE__{} = instance, key, value) do
    merge_context(instance, %{normalize_key(key) => value})
  end

  @doc """
  Merges values into the instance context and records them for the next commit.
  """
  @spec merge_context(t(), map()) :: t()
  def merge_context(%__MODULE__{} = instance, values) when is_map(values) do
    values = normalize_keys(values)

    %{
      instance
      | context: Map.merge(instance.context, values),
        changes: %{instance.changes | context: Map.merge(instance.changes.context, values)}
    }
  end

  @doc """
  Marks the instance as completed for the next commit.

  Completed instances are retained by the new storage API. Retention and
  purging are separate concerns.
  """
  @spec complete(t()) :: t()
  def complete(%__MODULE__{} = instance) do
    %{instance | status: :completed, changes: %{instance.changes | status: :completed}}
  end

  @doc """
  Returns the accumulated state, context, and status changes.
  """
  @spec changes(t()) :: changes()
  def changes(%__MODULE__{} = instance), do: instance.changes

  @doc """
  Clears changes after an instance has been persisted.
  """
  @spec clear_changes(t()) :: t()
  def clear_changes(%__MODULE__{} = instance) do
    %{instance | changes: %{state: %{}, context: %{}, status: nil}}
  end

  @doc false
  @spec from_legacy(map()) :: t()
  def from_legacy(legacy) when is_map(legacy) do
    %__MODULE__{
      key: Map.fetch!(legacy, :uuid),
      saga: Map.fetch!(legacy, :saga_name),
      status: if(Map.get(legacy, :marked_as_completed, false), do: :completed, else: :active),
      state: normalize_keys(Map.get(legacy, :states) || %{}),
      context: normalize_keys(Map.get(legacy, :context) || %{}),
      version: Map.get(legacy, :lock_version),
      inserted_at: Map.get(legacy, :inserted_at),
      updated_at: Map.get(legacy, :updated_at)
    }
  end

  @doc false
  @spec apply_changes(t(), changes()) :: t()
  def apply_changes(%__MODULE__{} = instance, changes) do
    instance
    |> merge_state(Map.get(changes, :state, %{}))
    |> merge_context(Map.get(changes, :context, %{}))
    |> apply_status(Map.get(changes, :status))
  end

  defp apply_status(instance, :completed), do: complete(instance)
  defp apply_status(instance, nil), do: instance

  defp normalize_keys(values) do
    Map.new(values, fn {key, value} -> {normalize_key(key), value} end)
  end

  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)

  defp normalize_key(key) do
    raise ArgumentError, "state and context keys must be strings or atoms, got: #{inspect(key)}"
  end
end
