import Config

config :logger, level: :warning

config :saga_weaver, SagaWeaver.Test.Repo,
  migration_lock: false,
  name: SagaWeaver.Test.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: System.get_env("DB_NAME", "saga_weaver_test"),
  priv: "test/support/migrations/postgres",
  stacktrace: true

config :saga_weaver,
  ecto_repos: [SagaWeaver.Test.Repo]
