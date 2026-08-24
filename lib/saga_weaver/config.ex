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

  @doc """
  Resolves and validates configuration for a facade.
  """
  @spec fetch(atom(), module(), keyword()) :: {:ok, t()} | {:error, term()}
  def fetch(otp_app, facade, overrides \\ []) do
    config =
      otp_app
      |> Application.get_env(facade, [])
      |> Keyword.merge(overrides)

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
end
