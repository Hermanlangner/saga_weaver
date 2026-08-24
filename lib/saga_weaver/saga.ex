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

  defmacro __using__(opts) do
    unless opts == [] do
      raise ArgumentError, "use SagaWeaver.Saga does not accept options"
    end

    quote do
      @behaviour SagaWeaver.Saga

      @doc "Ignores messages not matched by a saga-specific route clause."
      @impl SagaWeaver.Saga
      def route(_message), do: :ignore

      @doc "Returns an error for messages not matched by a saga-specific handler."
      @impl SagaWeaver.Saga
      def handle(_instance, _message), do: {:error, :unhandled_message}

      defoverridable handle: 2, route: 1
    end
  end
end
