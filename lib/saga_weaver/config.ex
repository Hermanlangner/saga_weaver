defmodule SagaWeaver.Config do
  @moduledoc """
  Validates and resolves SagaWeaver facade configuration.

  Applications normally configure an application-owned facade rather than
  calling this module directly.
  """

  alias SagaWeaver.Storage

  @type t :: %__MODULE__{
          otp_app: atom(),
          facade: module(),
          storage: Storage.adapter(),
          max_retries: non_neg_integer(),
          retry_backoff: non_neg_integer()
        }

  @enforce_keys [:otp_app, :facade, :storage]
  defstruct [:otp_app, :facade, :storage, max_retries: 5, retry_backoff: 1]

  @schema NimbleOptions.new!(
            storage: [type: :any, required: true],
            max_retries: [type: :non_neg_integer, default: 5],
            retry_backoff: [type: :non_neg_integer, default: 1]
          )

  @legacy_options [:storage_adapter, :repo, :host, :port, :database, :namespace, :connection]

  @doc """
  Resolves and validates configuration for a facade.
  """
  @spec fetch(atom(), module(), keyword()) :: {:ok, t()} | {:error, term()}
  def fetch(otp_app, facade, overrides \\ []) do
    config =
      otp_app
      |> Application.get_env(facade, [])
      |> Keyword.merge(overrides)
      |> normalize_legacy()

    with {:ok, validated} <- NimbleOptions.validate(config, @schema),
         {:ok, {adapter, adapter_opts}} <- Storage.validate(validated[:storage]) do
      storage =
        {adapter,
         Keyword.merge(
           [max_retries: validated[:max_retries], retry_backoff: validated[:retry_backoff]],
           adapter_opts
         )}

      {:ok,
       %__MODULE__{
         otp_app: otp_app,
         facade: facade,
         storage: storage,
         max_retries: validated[:max_retries],
         retry_backoff: validated[:retry_backoff]
       }}
    end
  end

  @doc """
  Resolves configuration and raises if it is invalid.
  """
  @spec fetch!(atom(), module(), keyword()) :: t()
  def fetch!(otp_app, facade, overrides \\ []) do
    case fetch(otp_app, facade, overrides) do
      {:ok, config} ->
        config

      {:error, reason} ->
        raise ArgumentError, "invalid SagaWeaver configuration: #{inspect(reason)}"
    end
  end

  @doc "Returns the deprecated global Redis host setting."
  @spec host() :: term()
  def host, do: config_value(:host)

  @doc "Returns the deprecated global Redis port setting."
  @spec port() :: term()
  def port, do: config_value(:port)

  @doc "Returns the deprecated global database setting."
  @spec database() :: term()
  def database, do: config_value(:database)

  @doc "Returns the deprecated global Redis namespace setting."
  @spec namespace() :: term()
  def namespace, do: config_value(:namespace)

  @doc "Returns the deprecated global Ecto repository setting."
  @spec repo() :: term()
  def repo, do: config_value(:repo)

  @doc "Returns the deprecated global storage adapter setting."
  @spec storage_adapter() :: term()
  def storage_adapter, do: config_value(:storage_adapter)

  @doc """
  Returns the configuration value for the given key.
  """
  @spec config_value(atom()) :: any()
  def config_value(key) do
    :saga_weaver
    |> Application.get_env(SagaWeaver, [])
    |> Keyword.get(key)
  end

  defp normalize_legacy(config) do
    if Keyword.has_key?(config, :storage) do
      Keyword.drop(config, @legacy_options)
    else
      case Keyword.get(config, :storage_adapter) do
        SagaWeaver.Adapters.PostgresAdapter ->
          translate_legacy(
            config,
            {SagaWeaver.Storage.Postgres, repo: Keyword.get(config, :repo)}
          )

        SagaWeaver.Adapters.RedisAdapter ->
          translate_legacy(
            config,
            {SagaWeaver.Storage.Redis,
             connection: Keyword.get(config, :connection),
             namespace: Keyword.get(config, :namespace)}
          )

        nil ->
          config

        adapter ->
          translate_legacy(config, {adapter, config})
      end
    end
  end

  defp translate_legacy(config, storage) do
    config
    |> Keyword.drop(@legacy_options)
    |> Keyword.put(:storage, storage)
  end
end
