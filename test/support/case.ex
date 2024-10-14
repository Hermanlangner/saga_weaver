defmodule SagaWeaver.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias SagaWeaver.Test.Repo

      import Ecto.Changeset
      import Ecto.Query
      import SagaWeaver.DataCase
    end
  end

  setup tags do
    __MODULE__.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(SagaWeaver.Test.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    case :gen_tcp.connect(~c"localhost", 6379, []) do
      {:ok, socket} ->
        :ok = :gen_tcp.close(socket)

      {:error, reason} ->
        Mix.raise(
          "Cannot connect to Redis (http://localhost:6379): #{:inet.format_error(reason)}"
        )
    end
  end
end
