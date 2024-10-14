defmodule SagaWeaver.Config do
  @moduledoc false

  @default_config %{}

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
    case Application.get_env(:saga_weaver, SagaWeaver) |> Keyword.get(key) do
      nil -> Map.get(@default_config, key)
      value -> value
    end
  end
end
