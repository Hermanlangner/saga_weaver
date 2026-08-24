defmodule SagaWeaver.Testing do
  @moduledoc """
  Helpers for isolated saga tests using `SagaWeaver.Storage.Memory`.

  Start the memory storage under the ExUnit test supervisor, then pass the
  returned options to the direct API:

      storage = start_supervised!(SagaWeaver.Storage.Memory)
      options = SagaWeaver.Testing.options(storage)

      SagaWeaver.handle(MySaga, message, options)
  """

  alias SagaWeaver.Storage.Memory

  @doc """
  Returns direct-API options for a supervised memory storage process.

  Additional options override the generated storage option.
  """
  @spec options(GenServer.server(), keyword()) :: keyword()
  def options(server, overrides \\ []) when is_list(overrides) do
    Keyword.put_new(overrides, :storage, {Memory, name: server})
  end
end
