[![Coverage Status](https://coveralls.io/repos/github/Hermanlangner/saga_weaver/badge.svg?branch=main)](https://coveralls.io/github/Hermanlangner/saga_weaver?branch=main)
# SagaWeaver
A saga pattern library to help manage distributed message orchestration


**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `saga_weaver` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:saga_weaver, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/saga_weaver>.

## Roadmap

**Developer Experience & Quality**

- [] Clean up tests to run for multiple adapters as a suite: Enhance the test suite to ensure compatibility and reliability across different storage adapters.
- [] Generate migration for setup: Provide mix tasks to generate necessary database migrations for easy setup.
- [] Make atoms work correctly for PostgreSQL adapters: Ensure that atoms are handled appropriately when using PostgreSQL as the storage backend.
- [] Ensure workflows are as expected if saga is killed while processing: Improve fault tolerance by handling unexpected terminations gracefully.
- [] Adopt Nimble Config for better configs: Utilize NimbleConfig for more robust and flexible configuration management.
**Features**
- [] Allow capability to schedule timeouts for timeouts: Implement functionality to handle timeouts, allowing sagas to be scheduled for timeout actions.
- [] Store historic completed sagas with a TTL: Enable storage of completed sagas with a Time-To-Live (TTL) to retain history for a configurable duration.
- [] Add observability queries: Introduce built-in queries to monitor saga executions and states for better observability.
- [] Add alerting API: Provide an API for setting up alerts based on saga events or failures.
- [] Add telemetry: Integrate with Telemetry to offer insights into saga performance and metrics.
- [] Add UI to monitor and track sagas: Develop a web-based dashboard to visualize and manage sagas in real-time.
- [] Add SQLite adapter: Expand storage options by adding support for SQLite.
- [] Add native Elixir adapter: Implement an in-memory adapter for testing or lightweight use cases without external dependencies.