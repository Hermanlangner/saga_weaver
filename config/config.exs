import Config

config :logger, level: :warning

config :saga_weaver, SagaWeaver.Test.Repo,
  migration_lock: false,
  name: SagaWeaver.Test.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  queue_target: 5_000,
  queue_interval: 5_000,
  priv: "test/support/migrations/postgres",
  stacktrace: true,
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  database: System.get_env("POSTGRES_DB", "saga_weaver_test"),
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres")

# url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/saga_weaver_test"

config :saga_weaver,
  ecto_repos: [SagaWeaver.Test.Repo]
