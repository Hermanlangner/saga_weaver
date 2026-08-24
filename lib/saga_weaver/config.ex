defmodule SagaWeaver.Config do
  @moduledoc false

  def host, do: config_value(:host)
  def port, do: config_value(:port)
  def database, do: config_value(:database)
  def namespace, do: config_value(:namespace)
  def repo, do: config_value(:repo)
  def storage_adapter, do: config_value(:storage_adapter)

  @doc """
  Returns the configuration value for the given key.
  """
  @spec config_value(atom()) :: any()
  def config_value(key) do
    :saga_weaver
    |> Application.get_env(SagaWeaver, [])
    |> Keyword.get(key)
  end
end
