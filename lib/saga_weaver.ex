defmodule SagaWeaver do
  @moduledoc """
  Handles transport-agnostic saga messages through a stable public facade.

  A saga routes each incoming message to a stable instance key and returns an
  explicit transition from its `handle/2` callback. SagaWeaver persists that
  transition once through the configured storage implementation.

  Applications should normally define an application-owned facade:

      defmodule MyApp.Sagas do
        use SagaWeaver, otp_app: :my_app
      end

  Then handle and fetch instances through it:

      MyApp.Sagas.handle(MyApp.OrderSaga, event)
      MyApp.Sagas.fetch(MyApp.OrderSaga, "order:123")

  SagaWeaver's core is synchronous and does not require a supervision-tree
  child. Applications remain responsible for supervising resources such as
  their Ecto repository or Redix connection.
  """

  alias SagaWeaver.{Config, Engine, Error, Instance}

  @typedoc "The result of handling one routed saga message."
  @type handle_result ::
          {:ok, Instance.t()}
          | {:ignored, :unrouted | :not_started | :completed | term()}
          | {:error, Error.t()}

  @typedoc "The result of fetching a saga instance."
  @type fetch_result :: {:ok, Instance.t()} | {:error, :not_found | Error.t()}

  @doc "Defines an application-owned SagaWeaver facade."
  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    quote do
      @saga_weaver_otp_app unquote(otp_app)

      @doc "Returns the validated SagaWeaver configuration for this facade."
      def config(overrides \\ []) do
        SagaWeaver.Config.fetch!(@saga_weaver_otp_app, __MODULE__, overrides)
      end

      @doc "Handles one message for a saga through this facade."
      def handle(saga, message, overrides \\ []) do
        SagaWeaver.handle(
          saga,
          message,
          otp_app: @saga_weaver_otp_app,
          facade: __MODULE__,
          config: overrides
        )
      end

      @doc "Fetches a saga instance by its stable route key."
      def fetch(saga, key, overrides \\ []) do
        SagaWeaver.fetch(
          saga,
          key,
          otp_app: @saga_weaver_otp_app,
          facade: __MODULE__,
          config: overrides
        )
      end
    end
  end

  @doc """
  Handles one message for a saga.

  The saga's `route/1` callback decides whether the message starts, continues,
  or does not apply to an instance.
  """
  @spec handle(module(), term(), keyword()) :: handle_result()
  def handle(saga, message, opts \\ []) do
    case resolve_config(opts) do
      {:ok, config} -> Engine.handle(saga, message, config)
      {:error, reason} -> {:error, Error.new(:config, reason)}
    end
  end

  @doc """
  Fetches a saga instance by its stable route key.
  """
  @spec fetch(module(), String.t(), keyword()) :: fetch_result()
  def fetch(saga, key, opts \\ []) do
    case resolve_config(opts) do
      {:ok, config} -> Engine.fetch(saga, key, config)
      {:error, reason} -> {:error, Error.new(:config, reason)}
    end
  end

  defp resolve_config(opts) do
    otp_app = Keyword.get(opts, :otp_app, :saga_weaver)
    facade = Keyword.get(opts, :facade, __MODULE__)
    overrides = Keyword.get(opts, :config, Keyword.drop(opts, [:otp_app, :facade]))
    Config.fetch(otp_app, facade, overrides)
  end
end
