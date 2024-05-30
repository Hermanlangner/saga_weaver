ExUnit.start()

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])

Application.put_env(:saga_weaver, SagaWeaver,
  host: "localhost",
  port: 6379,
  namespace: "saga_weaver_test"
)

case :gen_tcp.connect(~c"localhost", 6379, []) do
  {:ok, socket} ->
    :ok = :gen_tcp.close(socket)

  {:error, reason} ->
    Mix.raise("Cannot connect to Redis (http://localhost:6379): #{:inet.format_error(reason)}")
end
