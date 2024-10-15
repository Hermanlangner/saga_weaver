[![Coverage Status](https://coveralls.io/repos/github/Hermanlangner/saga_weaver/badge.svg?branch=main)](https://coveralls.io/github/Hermanlangner/saga_weaver?branch=main)
# SagaWeaver

A library to help you execute distributed transactions using Sagas without needing to worry about transport layers or storage implementations.

## Inspiration

There are many situations where a saga can be created from 1 or more events, either through an external system or internal. Usually the pattern is implemented as part of a framework or messaging library. The goal of saga weaver is to let you hook into any method of transport (message queues or http) and still be able to run a saga.
Storage can be a big source of race conditions, that bring a lot of mental overhead while rolling your own. Saga weaver is made to take care of that layer for you by providing storage implementations or if that's not good enough, expose an interface for you to write your own if you would like a more efficient approach or use a different pattern.

Distributed transactions are already hard on their own, Saga Weaver lets you focus on building out your application rules rather than spending time on covering storage or transport race conditions.

## Design Approach

- All Saga Weaver adapters are built with optimistic concurrency as a first class citizen. While collisions are guarenteed, the most frequent scenario happens in a fan out fan in. Otherwise generally collisions are low.
- Life Cycles are fully configurable, The conditions to start a saga, fork a workflow, trigger a compensating transaction or close a saga are all simply your elixir code.
- Setting state and context is intended to `feel` like the live view flow, so that there's familiarity with the rest of your eco system.
- Any struct that participates in a Saga needs to be able to be transformed to the Saga identifier
- While an Inbox/Outbox pattern is not present, we follow that at least once delivery approach. It needs to be ensured that application logic supports it.

## Installation

SagaWeaver is published on [Hex](https://hexdocs.pm/saga_weaver), the package can be installed
by adding `saga_weaver` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:saga_weaver, "~> 0.2"}
  ]
end
```

- Add SagaWeaver to your `application.ex`

```elixir
children = [
      {SagaWeaver, []}
    ]
 ```

### Postgress

- If you're using Postgres, you need to generate a migration to setup the saga_weaver table

```elixir
  mix ecto.gen.migration add_saga_weaver_table
```

Then add the following to your migration

```elixir
  def change do
    create table(:sagaweaver_sagas) do
      add(:uuid, :string)
      add(:saga_name, :string)
      add(:states, :map, default: %{})
      add(:context, :map, default: %{})
      add(:marked_as_completed, :boolean, default: false)
      add(:lock_version, :integer, default: 1)

      timestamps()
    end

    create(index(:sagaweaver_sagas, [:uuid], unique: true))
  end
```

- Add the config to `config.exs` and set your Repo and Adapter

```elixir
config :saga_weaver, SagaWeaver,
  storage_adapter: SagaWeaver.Adapters.PostgresAdapter,
  repo: MyApp.Repo
```

### Redis

add your redis config to `config.exs`

```elixir
config :saga_weaver, SagaWeaver,
  host: "localhost",
  port: 6379,
  namespace: "my_app",
  storage_adapter: SagaWeaver.Adapters.RedisAdapter,
```

## Example

A simple version of a saga, with one created message and one close message. We can define it as follows

```elixir
defmodule StartSagaMessage do
  defstruct [:id, :name]
end

defmodule CloseSagaMessage do
  defstruct [:external_id, :fanout_id]
end

defmodule SimpleSaga do
  use SagaWeaver.Saga,
    started_by: [StartSagaMessage],
    identity_key_mapping: %{
      StartSagaMessage => fn message -> %{id: message.id} end,
      CloseSagaMessage => fn message -> %{id: message.external_id} end
    }

  alias SagaWeaver.SagaSchema

  def handle_message(%SagaSchema{} = instance, %StartSagaMessage{} = message) do
    case instance.states["start_handled"] do
      true ->
        IO.puts("Start Message already handled for id: #{message.id}")

      _other ->
        IO.puts("Starting Saga for id: #{message.id}")
        # Do initial setup
    end

    {:ok,
     instance
     |> assign_state("start_handled", true)}
  end

  def handle_message(%SagaSchema{} = instance, %CloseSagaMessage{} = message) do
    instance = instance |> assign_state("close_handled", true)

    if ready_to_complete?(instance) do
      IO.puts("All conditions for closure have been met, closing")
      {:ok, instance |> mark_as_completed()}
    else
      {:ok, instance}
    end
  end

  defp ready_to_complete?(instance) do
    instance.states["start_handled"] && instance.states["close_handled"]
  end
end

```

This basic saga gets started with the Start message and closes when the accompanying Close message happens.
Let's see how this pans out.

- Ensure you're fully migrated `mix ecto.migrate`
- Open up your shell `iex -S mix`
- Setup some structs from the above example

```elixir
start_message = %StartSagaMessage{id: 1, name: "started"}
close_message = %CloseSagaMessage{external_id: 1, fanout_id: 24}
fake_close_message = %CloseSagaMessage{external_id: 2, fanout_id: 23}
```

Let's try and start a saga.
Run

```elixir
SagaWeaver.execute_saga(SimpleSaga, start_message)
```

The should be output for
`Starting Saga for id: 1`

If you run the command a second time, you should get
`Start Message already handled for id: 1`

Lets try and handle a close message that can't be associated to the saga

```elixir
SagaWeaver.execute_saga(SimpleSaga, fake_close_message)
```

you will get

```elixir
{:noop,
 "No active Sagas were found for this message, this message also does not start a new Saga."}
```

Let's trigger a message that will close the Saga

```elixir
SagaWeaver.execute_saga(SimpleSaga, close_message)
```

`All conditions for closure have been met, closing`

## `use Saga`

A breakdown on how to use a saga. All you need is a starting message, and an identity map

```elixir
    use SagaWeaver.Saga,
      started_by: [StartSagaMessage],
      identity_key_mapping: %{
        StartSagaMessage => fn message -> %{id: message.id} end,
        CloseSagaMessage => fn message -> %{id: message.external_id} end
      }

```

### Started By

`started_by` is the bread and butter of SagaWeaver. To have a valid Saga you need at least 1 struct that starts a Saga. It's possible for all messages to start a saga, and there is no required order. You can handle it through setting the state to co-ordinate the transaction.

```elixir
ready_for_next_step = instance.states["start_message_1"] && instance.states["start_message_2"]

if read_for_next_step do
 ## Logic to kick off next step process
end
```

### identity_key_mapping

In order to function with the default SagaWeaver configuration, each struct that is handled needs a map setup to extract elements to uniquely identify the saga
In the format

```elixir
my_identity_mapping = %{
  MyMessageModule => function_to_extract_context.(message)
}
```

It is required for scenarios where external Api's or domains have a different name for the identifier and you need the ability to correlate them.
In the future more sensible defaults could be worth it.

### Setting State

Each handler is passed an instance of a Saga where you can set states to manage your lifecycle.
See more here - add link to hex.pm

### Setting Context

Context is for information that's not related to managing the state of the saga, but is needed to trigger events or possibly combined on closure
See more here - add link to hex.pm

### Completing A saga

When either all your conditions for completion or rolling back has been completed. The final action you need to do is complete your saga. It's the equivalent to commiting a transaction or completing a rollback in sql.

```elixir
 instance |> mark_as_completed()
```

If sagas are not closed, the transaction will never commit and until timeouts are added will have your application in a "stuck" state.

## Roadmap

**Developer Experience & Quality**

- [ ] Clean up tests to run for multiple adapters as a suite: Enhance the test suite to ensure compatibility and reliability across different storage adapters.
- [ ] Generate migration for setup: Provide mix tasks to generate necessary database migrations for easy setup.
- [ ] Make atoms work correctly for PostgreSQL adapters: Ensure that atoms are handled appropriately when using PostgreSQL as the storage backend.
- [ ] Ensure workflows are as expected if saga is killed while processing: Improve fault tolerance by handling unexpected terminations gracefully.
- [ ] Adopt Nimble Config for better configs: Utilize NimbleConfig for more robust and flexible configuration management.

**Features**

- [ ] Allow capability to schedule timeouts for timeouts: Implement functionality to handle timeouts, allowing sagas to be scheduled for timeout actions.
- [ ] Store historic completed sagas with a TTL: Enable storage of completed sagas with a Time-To-Live (TTL) to retain history for a configurable duration.
- [ ] Add observability queries: Introduce built-in queries to monitor saga executions and states for better observability.
- [ ] Add alerting API: Provide an API for setting up alerts based on saga events or failures.
- [ ] Add telemetry: Integrate with Telemetry to offer insights into saga performance and metrics.
- [ ] Add UI to monitor and track sagas: Develop a web-based dashboard to visualize and manage sagas in real-time.
- [ ] Add SQLite adapter: Expand storage options by adding support for SQLite.
- [ ] Add native Elixir adapter: Implement an in-memory adapter for testing or lightweight use cases without external dependencies.
- [ ] Allow configurable retries and timeouts
- [ ] Add pooling to Redis Adapter

## Maintainer

Maintained by Herman Langner, feel free to reach out on [twitter](https://x.com/HermanLangner).
