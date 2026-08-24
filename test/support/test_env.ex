defmodule SagaWeaver.TestEnv do
  @moduledoc false

  def put_env(app, key, value) do
    original = Application.fetch_env(app, key)
    Application.put_env(app, key, value)

    fn -> restore_env(app, key, original) end
  end

  defp restore_env(app, key, {:ok, value}), do: Application.put_env(app, key, value)
  defp restore_env(app, key, :error), do: Application.delete_env(app, key)
end
