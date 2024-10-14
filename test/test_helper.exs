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

case :gen_tcp.connect(~c"localhost", 6379, []) do
  {:ok, socket} ->
    :ok = :gen_tcp.close(socket)

  {:error, reason} ->
    Mix.raise("Cannot connect to Redis (http://localhost:6379): #{:inet.format_error(reason)}")

    Ecto.Adapters.SQL.Sandbox.mode(SagaWeaver.Test.Repo, {:shared, self()})
end
