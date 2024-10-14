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
  end
end
