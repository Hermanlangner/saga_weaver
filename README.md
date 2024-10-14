[![Coverage Status](https://coveralls.io/repos/github/Hermanlangner/saga_weaver/badge.svg?branch=main)](https://coveralls.io/github/Hermanlangner/saga_weaver?branch=main)
# SagaWeaver

A library to help you execute distributed transactions using Sagas without needing to worry about transport layers or storage implementations.

# Inspiration

There are many situations where a saga can be created from 1 or more events, either through an external system or internal. Usually the pattern is implemented as part of a framework or messaging library. The goal of saga weaver is to let you hook into any method of transport (message queues or http) and still be able to run a saga.
Storage can be a big source of race conditions, that bring a lot of mental overhead while rolling your own. Saga weaver is made to take care of that layer for you by providing storage implementations or if that's not good enough, expose an interface for you to write your own if you would like a more efficient approach or use a different pattern.

Distributed transactions are already hard on their own, Saga Weaver lets you focus on building out your application rules rather than spending time on covering storage or transport race conditions.

# Design Approach

- All Saga Weaver adapters are built with optimistic concurrency as a first class citizen. While collisions are guarenteed, the most frequent scenario happens in a fan out fan in. Otherwise generally collisions are low.
- Life Cycles are fully configurable, The conditions to start a saga, fork a workflow, trigger a compensating transaction or close a saga are all simply your elixir code.
- Setting state and context is intended to `feel` like the live view flow, so that there's familiarity with the rest of your eco system.
- Any struct that participates in a Saga needs to be able to be transformed to the Saga identifier

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

- Add SagaWeaver to your application

```elixir
children = [
      {SagaWeaver, []}
    ]
 ```

### Postgress

- If you're using Postgress, you need to generate a migration to setup the saga_weaver table

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

- Add the config and set your Repo and Adapter

```elixir
config :saga_weaver, SagaWeaver,
  host: "localhost",
  port: 6379,
  namespace: "saga_weaver_test",
  storage_adapter: SagaWeaver.Adapters.PostgresAdapter,
  repo: SagaWeaver.Test.Repo
```

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