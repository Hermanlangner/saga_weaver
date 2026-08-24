defmodule SagaWeaver.Storage do
  @moduledoc """
  The storage extension contract for SagaWeaver.

  Storage implementations receive validated adapter options and operate on
  `%SagaWeaver.Instance{}` values. Implementations must make `insert_new/2`
  idempotent and merge disjoint changes atomically in `commit/3`.
  """

  alias SagaWeaver.Instance

  @type adapter :: {module(), keyword()}
  @type reason :: :not_found | :conflict | term()

  @doc "Validates backend-specific options and returns their normalized form."
  @callback validate_options(keyword()) :: {:ok, keyword()} | {:error, term()}

  @doc "Fetches an instance by its durable key."
  @callback fetch(keyword(), String.t()) :: {:ok, Instance.t()} | {:error, reason()}

  @doc "Idempotently inserts a new instance or returns the existing instance."
  @callback insert_new(keyword(), Instance.t()) :: {:ok, Instance.t()} | {:error, reason()}

  @doc "Atomically applies one state, context, and status delta."
  @callback commit(keyword(), Instance.t(), Instance.changes()) ::
              {:ok, Instance.t()} | {:error, reason()}

  @doc "Validates a storage adapter and its options."
  @spec validate(adapter()) :: {:ok, adapter()} | {:error, term()}
  def validate({adapter, opts}) when is_atom(adapter) and is_list(opts) do
    with {:module, ^adapter} <- Code.ensure_loaded(adapter),
         true <- function_exported?(adapter, :validate_options, 1) do
      case adapter.validate_options(opts) do
        {:ok, validated_opts} -> {:ok, {adapter, validated_opts}}
        {:error, reason} -> {:error, reason}
      end
    else
      _result -> {:error, {:invalid_storage, {:missing_callback, adapter, :validate_options, 1}}}
    end
  end

  def validate(storage), do: {:error, {:invalid_storage, storage}}

  @doc "Fetches an instance while emitting a storage Telemetry span."
  @spec fetch(adapter(), String.t()) :: {:ok, Instance.t()} | {:error, reason()}
  def fetch({adapter, opts}, key) do
    span(adapter, :fetch, key, fn -> adapter.fetch(opts, key) end)
  end

  @doc "Inserts an instance while emitting a storage Telemetry span."
  @spec insert_new(adapter(), Instance.t()) :: {:ok, Instance.t()} | {:error, reason()}
  def insert_new({adapter, opts}, %Instance{} = instance) do
    span(adapter, :insert_new, instance.key, fn -> adapter.insert_new(opts, instance) end)
  end

  @doc "Commits an instance delta while emitting storage Telemetry events."
  @spec commit(adapter(), Instance.t(), Instance.changes()) ::
          {:ok, Instance.t()} | {:error, reason()}
  def commit({adapter, opts}, %Instance{} = instance, changes) do
    result =
      span(adapter, :commit, instance.key, fn -> adapter.commit(opts, instance, changes) end)

    if match?({:error, :conflict}, result) do
      :telemetry.execute(
        [:saga_weaver, :storage, :conflict],
        %{system_time: System.system_time()},
        %{storage: adapter, key: instance.key}
      )
    end

    result
  end

  defp span(adapter, operation, key, fun) do
    :telemetry.span(
      [:saga_weaver, :storage, operation],
      %{storage: adapter, key: key},
      fn -> {fun.(), %{storage: adapter, key: key}} end
    )
  rescue
    error -> {:error, {:exception, error}}
  catch
    kind, reason -> {:error, {kind, reason}}
  end
end
