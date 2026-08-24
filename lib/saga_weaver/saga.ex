defmodule SagaWeaver.SagaBehaviour do
  @moduledoc false

  @doc "Returns the name persisted for legacy saga instances."
  @callback entity_name() :: atom()

  @doc "Returns message modules that may start a legacy saga."
  @callback started_by() :: [module()]

  @doc "Returns legacy message-to-identifier mappings."
  @callback identity_key_mapping() :: %{module() => (term() -> map())}

  @doc "Handles a message through the legacy saga API."
  @callback handle_message(SagaWeaver.SagaSchema.t(), any()) ::
              {:ok, SagaWeaver.SagaSchema.t()} | {:error, any()}
end

defmodule SagaWeaver.Saga do
  @moduledoc """
  Defines the routing and transition callbacks for a saga.

  `route/1` combines correlation and lifecycle intent. It returns a stable key
  and states whether a message may create an instance or only continue one.
  `handle/2` receives a `%SagaWeaver.Instance{}` and returns the transition to
  commit.

      defmodule MyApp.OrderSaga do
        use SagaWeaver.Saga

        alias SagaWeaver.Instance

        @impl true
        def route(%OrderPlaced{order_id: id}), do: {:start, "order:\#{id}"}
        def route(%PaymentCaptured{order_id: id}), do: {:continue, "order:\#{id}"}
        def route(_message), do: :ignore

        @impl true
        def handle(instance, %OrderPlaced{}) do
          {:ok, Instance.put_state(instance, :placed, true)}
        end

        def handle(instance, %PaymentCaptured{}) do
          {:complete, Instance.put_state(instance, :paid, true)}
        end
      end

  Returning `{:ok, instance}` keeps the saga active. Returning
  `{:complete, instance}` retains a completed tombstone. `{:ignore, reason}`
  acknowledges the message without persistence, while `{:error, reason}` is
  returned as a structured callback error.

  The `started_by` and `identity_key_mapping` options remain available for the
  deprecated 0.2 API. New sagas should implement `route/1` instead.
  """

  @typedoc "The result of routing an incoming message."
  @type route_result :: {:start, String.t()} | {:continue, String.t()} | :ignore

  @typedoc "The result of handling a routed message."
  @type handle_result ::
          {:ok, SagaWeaver.Instance.t()}
          | {:complete, SagaWeaver.Instance.t()}
          | {:ignore, term()}
          | {:error, term()}

  @doc "Routes a message to a stable saga key or ignores it."
  @callback route(term()) :: route_result()

  @doc "Returns the transition produced by one routed message."
  @callback handle(SagaWeaver.Instance.t(), term()) :: handle_result()

  alias SagaWeaver.Adapters.StorageAdapter

  defmacro __using__(opts) do
    started_by = Keyword.get(opts, :started_by, [])
    how_to_find_saga = Keyword.get(opts, :identity_key_mapping, {:%{}, [], []})
    legacy? = Keyword.has_key?(opts, :started_by) or Keyword.has_key?(opts, :identity_key_mapping)

    quote do
      @behaviour SagaWeaver.SagaBehaviour
      @behaviour SagaWeaver.Saga

      @doc false
      def __saga_weaver_api__, do: unquote(if(legacy?, do: :v1, else: :v2))

      @doc "Ignores messages not matched by a saga-specific route clause."
      @impl SagaWeaver.Saga
      def route(_message), do: :ignore

      @doc "Returns an error for messages not matched by a saga-specific handler."
      @impl SagaWeaver.Saga
      def handle(_instance, _message), do: {:error, :unhandled_message}

      @doc "Returns the name persisted for legacy saga instances."
      def entity_name, do: __MODULE__

      @doc "Returns message modules that may start a legacy saga."
      def started_by, do: unquote(started_by)

      @doc "Returns legacy message-to-identifier mappings."
      def identity_key_mapping do
        unquote(how_to_find_saga)
      end

      @doc "Handles a message through the legacy saga API."
      @spec handle_message(SagaWeaver.SagaSchema.t(), any()) ::
              {:ok, SagaWeaver.SagaSchema.t()} | {:error, any()}
      def handle_message(_entity, _message), do: {:error, "Message not recognized"}

      @doc "Assigns one state value through the legacy storage API."
      def assign_state(instance, key, value) do
        assign_state(instance, %{key => value})
      end

      defoverridable handle_message: 2,
                     handle: 2,
                     route: 1,
                     started_by: 0,
                     entity_name: 0,
                     identity_key_mapping: 0

      @doc "Assigns state values through the legacy storage API."
      def assign_state(instance, state_map) do
        {:ok, instance} = StorageAdapter.assign_state(instance, state_map)
        instance
      end

      @doc "Assigns one context value through the legacy storage API."
      def assign_context(instance, key, value) do
        assign_context(instance, %{key => value})
      end

      @doc "Assigns context values through the legacy storage API."
      def assign_context(instance, context_map) do
        {:ok, instance} =
          StorageAdapter.assign_context(instance, context_map)

        instance
      end

      @doc "Marks a saga as completed through the legacy storage API."
      def mark_as_completed(instance) do
        {:ok, instance} = StorageAdapter.mark_as_completed(instance)
        instance
      end
    end
  end
end
