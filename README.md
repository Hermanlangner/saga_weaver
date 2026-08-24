[![Coverage Status](https://coveralls.io/repos/github/Hermanlangner/saga_weaver/badge.svg?branch=main)](https://coveralls.io/github/Hermanlangner/saga_weaver?branch=main)

# SagaWeaver

SagaWeaver coordinates long-running, distributed workflows without owning your
transport layer. HTTP handlers, message consumers, jobs, and internal Elixir
code can all send events through the same saga definition.

SagaWeaver provides:

- Explicit routing for starting and continuing saga instances.
- Concurrency-safe PostgreSQL and Redis storage.
- Pure state transitions committed once per handled message.
- Retained completion records for replay protection.
- Application-owned configuration and infrastructure.
- Structured errors and Telemetry events.

SagaWeaver assumes at-least-once message delivery. Application side effects
must therefore be idempotent.

## Installation

Add SagaWeaver and the driver required by your chosen storage:

```elixir
def deps do
  [
    {:saga_weaver, "~> 0.3"},
    {:postgrex, ">= 0.0.0"}
  ]
end
```

Then fetch dependencies and generate setup instructions:

```shell
mix deps.get
mix saga_weaver.install --storage postgres
```

For Redis:

```shell
mix saga_weaver.install --storage redis
```

SagaWeaver's core is synchronous and does not require a child in your
application supervision tree. Your application owns resources such as its Ecto
repository and Redix connection.

## Application Facade

Define a facade so configuration belongs to your application rather than a
global SagaWeaver singleton:

```elixir
defmodule MyApp.Sagas do
  use SagaWeaver, otp_app: :my_app
end
```

### PostgreSQL

Configure the facade with your existing, supervised Ecto repository:

```elixir
config :my_app, MyApp.Sagas,
  storage: {SagaWeaver.Storage.Postgres, repo: MyApp.Repo}
```

`mix saga_weaver.install --storage postgres` generates the
`sagaweaver_sagas` migration.

### Redis

Add a named Redix connection to your application supervision tree:

```elixir
children = [
  {Redix, name: MyApp.SagaRedis, host: "localhost", port: 6379}
]
```

Then pass the connection name to the facade configuration:

```elixir
config :my_app, MyApp.Sagas,
  storage: {
    SagaWeaver.Storage.Redis,
    connection: MyApp.SagaRedis,
    namespace: "my_app"
  }
```

SagaWeaver does not create hidden Redis connections. This keeps ownership,
authentication, TLS, pooling, and restart behavior under application control.

## Define A Saga

A saga implements two callbacks:

- `route/1` identifies the instance and says whether the message may start it.
- `handle/2` returns the state transition to persist.

```elixir
defmodule MyApp.Events.OrderPlaced do
  defstruct [:order_id, :customer_id]
end

defmodule MyApp.Events.PaymentCaptured do
  defstruct [:order_id]
end

defmodule MyApp.OrderSaga do
  use SagaWeaver.Saga

  alias MyApp.Events.{OrderPlaced, PaymentCaptured}
  alias SagaWeaver.Instance

  @impl true
  def route(%OrderPlaced{order_id: id}), do: {:start, "order:#{id}"}
  def route(%PaymentCaptured{order_id: id}), do: {:continue, "order:#{id}"}
  def route(_message), do: :ignore

  @impl true
  def handle(instance, %OrderPlaced{} = event) do
    instance =
      instance
      |> Instance.put_state(:placed, true)
      |> Instance.put_context(:customer_id, event.customer_id)

    {:ok, instance}
  end

  def handle(instance, %PaymentCaptured{}) do
    instance = Instance.put_state(instance, :paid, true)

    if instance.state["placed"] do
      {:complete, instance}
    else
      {:ok, instance}
    end
  end
end
```

Route keys are durable storage identifiers shared by every saga in one storage
namespace. Use globally unique, stable strings such as `"order:123"` that do
not depend on module names or display labels. SagaWeaver rejects a key already
owned by a different saga.

### Routing Results

```elixir
{:start, "order:123"}    # Create if absent, otherwise continue it
{:continue, "order:123"} # Handle only when an instance already exists
:ignore                  # This saga is not interested in the message
```

An event routed with `:continue` before the starter returns
`{:ignored, :not_started}`. An unrelated event returns
`{:ignored, :unrouted}`.

### Handler Results

```elixir
{:ok, instance}       # Commit changes and remain active
{:complete, instance} # Commit changes and retain a completed tombstone
{:ignore, reason}     # Acknowledge without committing
{:error, reason}      # Return a structured callback error
```

`SagaWeaver.Instance` helpers are pure. State and context changes are committed
once after the callback succeeds, preventing partial writes when a later part
of a handler fails.

## Handle And Fetch

```elixir
event = %MyApp.Events.OrderPlaced{order_id: 123, customer_id: 42}

{:ok, instance} = MyApp.Sagas.handle(MyApp.OrderSaga, event)
{:ok, instance} = MyApp.Sagas.fetch(MyApp.OrderSaga, "order:123")
```

`handle/2` returns:

```elixir
{:ok, %SagaWeaver.Instance{}}
{:ignored, :unrouted | :not_started | :completed | term()}
{:error, %SagaWeaver.Error{}}
```

`fetch/2` returns:

```elixir
{:ok, %SagaWeaver.Instance{}}
{:error, :not_found}
{:error, %SagaWeaver.Error{}}
```

Completed instances remain fetchable and further messages return
`{:ignored, :completed}`. Retention and purging are separate policies; new code
must not rely on completion deleting records. Completion is terminal: stale
in-flight transitions cannot mutate a completed tombstone.

## State And Context

State contains values that drive the saga lifecycle. Context contains persisted
information needed by later handlers or side effects.

```elixir
instance
|> SagaWeaver.Instance.put_state(:payment_received, true)
|> SagaWeaver.Instance.merge_state(%{inventory_reserved: true})
|> SagaWeaver.Instance.put_context(:customer_id, 42)
```

Keys may be atoms or strings and are exposed consistently as strings across all
storage implementations.

## Testing

Use the supervised memory storage for isolated tests and examples:

```elixir
setup do
  storage = start_supervised!(SagaWeaver.Storage.Memory)
  %{saga_options: SagaWeaver.Testing.options(storage)}
end

test "completes an order", %{saga_options: options} do
  assert {:ok, instance} = SagaWeaver.handle(MyApp.OrderSaga, event, options)
  assert instance.state["placed"]
end
```

Run the complete executable quickstart with:

```shell
mix run examples/quickstart/order_saga.exs
```

## Telemetry

SagaWeaver emits start, stop, and exception spans plus lifecycle events:

```elixir
[:saga_weaver, :handle, :start]
[:saga_weaver, :handle, :stop]
[:saga_weaver, :handle, :exception]
[:saga_weaver, :storage, operation, :start]
[:saga_weaver, :storage, operation, :stop]
[:saga_weaver, :storage, operation, :exception]
[:saga_weaver, :storage, :conflict]
[:saga_weaver, :completion]
[:saga_weaver, :ignored]
```

Storage `operation` is `:fetch`, `:insert_new`, or `:commit`.

Metadata includes the saga, key, storage implementation, facade, result, or
ignore reason where applicable. Telemetry handlers run in the caller process
and should remain fast.

## Custom Storage

Custom storage implements `SagaWeaver.Storage`:

```elixir
@callback validate_options(keyword()) :: {:ok, keyword()} | {:error, term()}
@callback fetch(keyword(), String.t()) ::
            {:ok, SagaWeaver.Instance.t()} | {:error, term()}
@callback insert_new(keyword(), SagaWeaver.Instance.t()) ::
            {:ok, SagaWeaver.Instance.t()} | {:error, term()}
@callback commit(keyword(), SagaWeaver.Instance.t(), SagaWeaver.Instance.changes()) ::
            {:ok, SagaWeaver.Instance.t()} | {:error, term()}
```

`insert_new/2` must be idempotent. `commit/3` must atomically merge disjoint
state and context changes. Completed records must remain readable.

## Design Principles

- Transports remain application concerns.
- No process exists without a runtime responsibility.
- Configuration belongs to an application-owned facade.
- Expected failures use tagged results; unexpected callback exceptions become
  structured errors and Telemetry exception events.
- Storage implementations share one behavioral contract.
- Completion and data deletion are separate lifecycle decisions.

## Development

The repository pins Erlang and Elixir with [mise](https://mise.jdx.dev/):

```shell
mise trust
mise install
mix deps.get
mix test
```

If mise is not activated in your shell, run commands through it, for example
`mise exec -- mix test`.

## Roadmap

- Configurable completion retention and TTL purging.
- Timeout scheduling and retry policies.
- Observability queries and a monitoring interface.
- Additional storage implementations.

## Maintainer

Maintained by Herman Langner. Feedback and contributions are welcome on
[GitHub](https://github.com/Hermanlangner/saga_weaver).
