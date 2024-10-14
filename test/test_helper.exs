ExUnit.start()

Application.ensure_all_started(:postgrex)
ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])

SagaWeaver.Test.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(SagaWeaver.Test.Repo, :manual)
