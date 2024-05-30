defmodule SagaWeaver.Config do
  @moduledoc false

  @default_config %{
    saga_identifier: SagaWeaver.Identifiers.DefaultIdentifier,
    storage_adapter: SagaWeaver.Adapters.RedisAdapter,
    host: "localhostFail",
    port: 63_791,
    namespace: "saga_weaver"
  }

  def host, do: config_value(:host)
  def port, do: config_value(:port)
  def database, do: config_value(:database)
  def namespace, do: config_value(:namespace)

  @doc """
  Returns the configuration value for the given key.
  """
  @spec config_value(atom()) :: any()
  def config_value(key) do
    case Application.get_env(:saga_weaver, SagaWeaver)[key] do
      nil -> Map.get(@default_config, key)
      value -> value
    end
  end
end
