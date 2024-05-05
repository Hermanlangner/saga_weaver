defmodule ExSaga.RedisAdapter do
  @moduledoc """
  Redis adapter for ExSaga.

  FOR initial iterations I'm not going to fuss about creating tons of new connections to Redis.
  """
  alias Redix

  # Assuming Redis is running locally on the default port
  @redis_url "redis://localhost:6379"

  # Writes a record to Redis
  def write_record(key, value) do
    execute_command(["SET", key, value])
  end

  # Fetches a record from Redis
  def fetch_record(key) do
    execute_command(["GET", key])
  end

  # Locks a record for writes (simple locking mechanism)
  def lock_record(key, timeout \\ 3000) do
    # Attempt to set a lock key
    execute_command(["SET", "#{key}:lock", "locked", "NX", "PX", Integer.to_string(timeout)])
  end

  # Deletes a record from Redis
  def delete_record(key) do
    execute_command(["DEL", key])
  end

  # Helper function to execute a command and parse response
  defp execute_command(commands) do
    connection()
    |> Redix.command(commands)
    |> handle_response()
  end

  # Handle Redis response
  defp handle_response({:ok, result}), do: {:ok, result}
  defp handle_response({:error, reason}), do: {:error, reason}

  defp connection() do
    {:ok, conn} = Redix.start_link(@redis_url)
    conn
  end
end
