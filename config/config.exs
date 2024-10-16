import Config

config :logger, level: :warning

config :saga_weaver, SagaWeaver.Test.Repo,
  migration_lock: false,
  name: SagaWeaver.Test.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  priv: "test/support/migrations/postgres",
  stacktrace: true,
  hostname: "localhost",
  port: 5432,
  database: "saga_weaver_test",
  username: "postgres",
  password: "postgres"

# url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/saga_weaver_test"

config :saga_weaver,
  ecto_repos: [SagaWeaver.Test.Repo]
