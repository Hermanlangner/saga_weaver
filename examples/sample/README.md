# SagaWeaver Phoenix Sample

This Phoenix application demonstrates SagaWeaver 0.3 with an application-owned
facade and the app's existing Ecto repository.

## Run It

From this directory:

```shell
mix setup
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

The database configuration uses the usual `PGHOST`, `PGPORT`, `PGUSER`,
`PGPASSWORD`, and `PGDATABASE` environment variables. See
`config/runtime.exs` for production settings.

## Integration

`Sample.Sagas` is the application's public SagaWeaver facade:

```elixir
defmodule Sample.Sagas do
  use SagaWeaver, otp_app: :sample
end
```

It uses `Sample.Repo`, which is already supervised by the Phoenix application:

```elixir
config :sample, Sample.Sagas,
  storage: {SagaWeaver.Storage.Postgres, repo: Sample.Repo}
```

There is no SagaWeaver child process in `Sample.Application`.

`SimpleSaga` shows explicit start/continue routing, pure instance changes, and
retained completion. The sample test exercises the complete flow:

```shell
mix test test/sample/example_sage_test.exs
```

The important calls are:

```elixir
Sample.Sagas.handle(SimpleSaga, %StartSagaMessage{id: 1, name: "Start"})
Sample.Sagas.handle(SimpleSaga, %CloseSagaMessage{external_id: 1, fanout_id: 1})
Sample.Sagas.fetch(SimpleSaga, "simple:1")
```

See the repository root `README.md` for storage contracts, Telemetry events,
and testing helpers.
