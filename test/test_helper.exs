ExUnit.start()

Application.ensure_all_started(:postgrex)
ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])

SagaWeaver.Test.Repo.start_link()

Application.put_env(:saga_weaver, SagaWeaver,
  host: "localhost",
  port: 6379,
  namespace: "saga_weaver_test",
  repo: SagaWeaver.Test.Repo
)

Application.put_env(:saga_weaver, :repo, SagaWeaver.Test.Repo)

Ecto.Adapters.SQL.Sandbox.mode(SagaWeaver.Test.Repo, :manual)
