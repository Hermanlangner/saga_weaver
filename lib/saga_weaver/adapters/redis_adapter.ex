defmodule SagaWeaver.Adapters.RedisAdapter do
  @behaviour SagaWeaver.Adapters.StorageAdapter
  alias SagaWeaver.SagaSchema
  alias Redix

  def initialize_saga(%SagaSchema{} = saga) do
    conn = connection()

    retry_until_ok(fn ->
      retry_initialize_saga(conn, saga)
    end)
  end

  def retry_initialize_saga(conn, new_saga) do
    apply_watch(conn, new_saga.unique_identifier)

    case get_saga(new_saga.unique_identifier) do
      {:ok, :not_found} ->
        transaction_result =
          execute_transaction(conn, [["SET", new_saga.unique_identifier, encode_entity(new_saga)]])

        case transaction_result do
          :ok -> get_saga(new_saga.unique_identifier)
          {:error, :transaction_failed} -> :error
        end

      {:ok, saga} ->
        unwatch(conn)
        {:ok, saga}
    end
  end

  def saga_exists?(unique_identifier) do
    case key_exists?(unique_identifier) do
      {:ok, 1} ->
        true

      {:ok, 0} ->
        false
        # error -> handle_error(error)
    end
  end

  def get_saga(key) do
    case fetch_record(key) do
      {:ok, nil} -> {:ok, :not_found}
      {:ok, saga} -> {:ok, decode_entity(saga)}
      {:error, _} = error -> error
    end
  end

  def mark_as_completed(%SagaSchema{} = saga) do
    conn = connection()

    retry_until_ok(fn ->
      retry_mark_as_completed(conn, saga.unique_identifier)
    end)

    get_saga(saga.unique_identifier)
  end

  defp retry_mark_as_completed(conn, unique_identifier) do
    apply_watch(conn, unique_identifier)
    {:ok, saga} = get_saga(unique_identifier)
    saga = %SagaSchema{saga | marked_as_completed: true}

    transaction_result =
      execute_transaction(conn, [["SET", saga.unique_identifier, encode_entity(saga)]])

    case transaction_result do
      :ok -> {:ok, saga}
      {:error, :transaction_failed} -> :error
    end
  end

  def complete_saga(%SagaSchema{} = saga) do
    conn = connection()

    retry_until_ok(fn ->
      retry_complete_saga(conn, saga)
    end)

    :ok
  end

  def retry_complete_saga(conn, new_saga) do
    apply_watch(conn, new_saga.unique_identifier)

    case get_saga(new_saga.unique_identifier) do
      {:ok, :not_found} ->
        unwatch(conn)
        {:ok, :not_found}

      {:ok, saga} ->
        transaction_result =
          execute_transaction(conn, [["DEL", saga.unique_identifier]])

        case transaction_result do
          :ok -> {:ok, nil}
          {:error, :transaction_failed} -> :error
        end
    end
  end

  def assign_state(%SagaSchema{} = saga, state) do
    conn = connection()

    retry_until_ok(fn ->
      retry_assign_state(conn, saga.unique_identifier, state)
    end)

    get_saga(saga.unique_identifier)
  end

  defp retry_assign_state(conn, unique_identifier, state) do
    apply_watch(conn, unique_identifier)
    {:ok, saga} = get_saga(unique_identifier)
    saga = %SagaSchema{saga | states: Map.merge(saga.states, state)}

    transaction_result =
      execute_transaction(conn, [["SET", saga.unique_identifier, encode_entity(saga)]])

    case transaction_result do
      :ok -> {:ok, saga}
      {:error, :transaction_failed} -> :error
    end
  end

  def assign_context(%SagaSchema{} = saga, context) do
    conn = connection()

    retry_until_ok(fn ->
      retry_assign_context(conn, saga.unique_identifier, context)
    end)

    get_saga(saga.unique_identifier)
  end

  defp retry_assign_context(conn, unique_identifier, context) do
    apply_watch(conn, unique_identifier)
    {:ok, saga} = get_saga(unique_identifier)
    saga = %SagaSchema{saga | context: Map.merge(saga.context, context)}

    transaction_result =
      execute_transaction(conn, [["SET", saga.unique_identifier, encode_entity(saga)]])

    case transaction_result do
      :ok -> {:ok, saga}
      {:error, :transaction_failed} -> :error
    end
  end

  # Redis operations

  defp key_exists?(key) do
    connection()
    |> Redix.command(["EXISTS", key])
    |> handle_response()
  end

  defp fetch_record(key) do
    connection()
    |> Redix.command(["GET", key])
    |> handle_response()
  end

  # Helper functions

  defp connection() do
    case Redix.start_link("redis://localhost:6379") do
      {:ok, conn} -> conn
      error -> handle_error(error)
    end
  end

  defp apply_watch(conn, key) do
    Redix.command(conn, ["WATCH", key])
  end

  defp unwatch(conn) do
    Redix.command(conn, ["UNWATCH"])
  end

  defp execute_transaction(conn, commands) do
    case Redix.pipeline(conn, [["MULTI"] | commands ++ [["EXEC"]]]) do
      {:ok, ["OK", "QUEUED", nil]} ->
        {:error, :transaction_failed}

      {:ok, ["OK", "QUEUED", _]} ->
        :ok

      error ->
        handle_error(error)
    end
  end

  defp retry_until_ok(fun, delay \\ 0) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      :error ->
        Process.sleep(delay)
        retry_until_ok(fun, delay)
    end
  end

  defp handle_response({:ok, result}), do: {:ok, result}
  defp handle_response({:error, reason}), do: {:error, reason}

  defp handle_error({:error, reason}) do
    {:error, reason}
  end

  defp encode_entity(entity) do
    :erlang.term_to_binary(entity)
  end

  defp decode_entity(binary) do
    :erlang.binary_to_term(binary)
  end
end
