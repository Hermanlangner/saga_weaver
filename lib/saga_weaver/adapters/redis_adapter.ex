defmodule SagaWeaver.Adapters.RedisAdapter do
  @moduledoc false
  @behaviour SagaWeaver.Adapters.StorageAdapter
  alias Redix
  alias SagaWeaver.Config
  alias SagaWeaver.SagaSchema

  @spec initialize_saga(SagaSchema.t()) :: {:ok, SagaSchema.t()}
  def initialize_saga(%SagaSchema{} = saga) do
    conn = connection()

    retry_until_ok(fn ->
      retry_initialize_saga(conn, saga)
    end)
  end

  def retry_initialize_saga(conn, new_saga) do
    apply_watch(conn, new_saga.uuid)

    case get_saga(new_saga.uuid) do
      {:ok, :not_found} ->
        transaction_result =
          execute_transaction(conn, [
            ["SET", namespaced_key(new_saga.uuid), encode_entity(new_saga)]
          ])

        case transaction_result do
          :ok -> get_saga(new_saga.uuid)
          {:error, :transaction_failed} -> :error
        end

      {:ok, saga} ->
        unwatch(conn)
        {:ok, saga}
    end
  end

  def saga_exists?(uuid) do
    case key_exists?(uuid) do
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
      retry_mark_as_completed(conn, saga.uuid)
    end)

    get_saga(saga.uuid)
  end

  defp retry_mark_as_completed(conn, uuid) do
    apply_watch(conn, uuid)
    {:ok, saga} = get_saga(uuid)
    saga = %SagaSchema{saga | marked_as_completed: true}

    transaction_result =
      execute_transaction(conn, [
        ["SET", namespaced_key(saga.uuid), encode_entity(saga)]
      ])

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
    apply_watch(conn, new_saga.uuid)

    case get_saga(new_saga.uuid) do
      {:ok, :not_found} ->
        unwatch(conn)
        {:ok, :not_found}

      {:ok, saga} ->
        transaction_result =
          execute_transaction(conn, [["DEL", namespaced_key(saga.uuid)]])

        case transaction_result do
          :ok -> {:ok, nil}
          {:error, :transaction_failed} -> :error
        end
    end
  end

  def assign_state(%SagaSchema{} = saga, state) do
    conn = connection()

    retry_until_ok(fn ->
      retry_assign_state(conn, saga.uuid, state)
    end)

    get_saga(saga.uuid)
  end

  defp retry_assign_state(conn, uuid, state) do
    apply_watch(conn, uuid)
    {:ok, saga} = get_saga(uuid)
    saga = %SagaSchema{saga | states: Map.merge(saga.states, state)}

    transaction_result =
      execute_transaction(conn, [
        ["SET", namespaced_key(saga.uuid), encode_entity(saga)]
      ])

    case transaction_result do
      :ok ->
        {:ok, saga}

      {:error, :transaction_failed} ->
        :error
    end
  end

  def assign_context(%SagaSchema{} = saga, context) do
    conn = connection()

    retry_until_ok(fn ->
      retry_assign_context(conn, saga.uuid, context)
    end)

    get_saga(saga.uuid)
  end

  defp retry_assign_context(conn, uuid, context) do
    apply_watch(conn, uuid)
    {:ok, saga} = get_saga(uuid)
    saga = %SagaSchema{saga | context: Map.merge(saga.context, context)}

    transaction_result =
      execute_transaction(conn, [
        ["SET", namespaced_key(saga.uuid), encode_entity(saga)]
      ])

    case transaction_result do
      :ok -> {:ok, saga}
      {:error, :transaction_failed} -> :error
    end
  end

  # Redis operations

  defp key_exists?(key) do
    connection()
    |> Redix.command(["EXISTS", namespaced_key(key)])
    |> handle_response()
  end

  defp fetch_record(key) do
    connection()
    |> Redix.command(["GET", namespaced_key(key)])
    |> handle_response()
  end

  # Helper functions

  defp namespaced_key(key) do
    "#{Config.namespace()}:#{key}"
  end

  defp connection do
    case Redix.start_link("redis://#{Config.host()}:#{Config.port()}") do
      {:ok, conn} -> conn
      error -> handle_error(error)
    end
  end

  defp apply_watch(conn, key) do
    Redix.command(conn, ["WATCH", namespaced_key(key)])
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
