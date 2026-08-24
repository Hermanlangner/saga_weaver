defmodule SagaWeaver.Engine do
  @moduledoc false

  alias SagaWeaver.{Config, Error, Instance, Storage}

  @spec handle(module(), term(), Config.t()) :: SagaWeaver.handle_result()
  def handle(saga, message, %Config{} = config) when is_atom(saga) do
    metadata = %{saga: saga, facade: config.facade, storage: elem(config.storage, 0)}

    try do
      :telemetry.span([:saga_weaver, :handle], metadata, fn ->
        result = route_and_handle(saga, message, config)
        {result, Map.put(metadata, :result, result_type(result))}
      end)
    rescue
      error ->
        {:error,
         Error.new(:callback, error,
           message: "Saga callback raised: #{Exception.message(error)}",
           metadata: metadata
         )}
    catch
      kind, reason ->
        {:error,
         Error.new(:callback, {kind, reason},
           message: "Saga callback exited with #{kind}: #{inspect(reason)}",
           metadata: metadata
         )}
    end
  end

  @spec fetch(module(), String.t(), Config.t()) :: SagaWeaver.fetch_result()
  def fetch(saga, key, %Config{} = config) when is_atom(saga) and is_binary(key) do
    case Storage.fetch(config.storage, key) do
      {:ok, %Instance{} = instance} -> ensure_saga(instance, saga)
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, storage_error(reason, saga, key, config)}
    end
  end

  defp route_and_handle(saga, message, config) do
    case saga.route(message) do
      :ignore ->
        ignored(:unrouted, saga, nil)

      {:start, key} when is_binary(key) ->
        with {:ok, instance} <- fetch_or_start(saga, key, config) do
          handle_instance(saga, instance, message, config)
        end

      {:continue, key} when is_binary(key) ->
        with {:ok, instance} <- fetch_existing(saga, key, config) do
          handle_instance(saga, instance, message, config)
        end

      invalid ->
        {:error,
         Error.new(:routing, {:invalid_route, invalid},
           message: "route/1 must return {:start, key}, {:continue, key}, or :ignore",
           metadata: %{saga: saga}
         )}
    end
  end

  defp fetch_or_start(saga, key, config) do
    case Storage.fetch(config.storage, key) do
      {:ok, instance} -> active(instance, saga)
      {:error, :not_found} -> insert_new(saga, key, config)
      {:error, reason} -> {:error, storage_error(reason, saga, key, config)}
    end
  end

  defp fetch_existing(saga, key, config) do
    case Storage.fetch(config.storage, key) do
      {:ok, instance} -> active(instance, saga)
      {:error, :not_found} -> ignored(:not_started, saga, key)
      {:error, reason} -> {:error, storage_error(reason, saga, key, config)}
    end
  end

  defp insert_new(saga, key, config) do
    case Storage.insert_new(config.storage, Instance.new(saga, key)) do
      {:ok, instance} -> active(instance, saga)
      {:error, reason} -> {:error, storage_error(reason, saga, key, config)}
    end
  end

  defp active(%Instance{} = instance, saga) do
    with {:ok, instance} <- ensure_saga(instance, saga) do
      active_instance(instance, saga)
    end
  end

  defp active_instance(%Instance{status: :active} = instance, _saga), do: {:ok, instance}

  defp active_instance(%Instance{status: :completed, key: key}, saga),
    do: ignored(:completed, saga, key)

  defp ensure_saga(%Instance{saga: persisted} = instance, saga) do
    if persisted == Atom.to_string(saga) do
      {:ok, instance}
    else
      {:error,
       Error.new(:routing, {:saga_mismatch, persisted},
         message: "The route key belongs to a different saga",
         metadata: %{saga: saga, key: instance.key, persisted_saga: persisted}
       )}
    end
  end

  defp handle_instance(saga, instance, message, config) do
    case saga.handle(instance, message) do
      {:ok, %Instance{} = updated} ->
        commit_transition(saga, instance, updated, config)

      {:complete, %Instance{} = updated} ->
        commit_transition(saga, instance, Instance.complete(updated), config)

      {:ignore, reason} ->
        ignored(reason, saga, instance.key)

      {:error, reason} ->
        {:error, callback_error(reason, saga, instance.key)}

      invalid ->
        {:error, callback_error({:invalid_return, invalid}, saga, instance.key)}
    end
  end

  defp commit_transition(saga, original, updated, config) do
    if updated.key == original.key and updated.saga == original.saga do
      commit(saga, updated, config)
    else
      reason =
        {:invalid_instance_identity,
         %{
           expected: %{key: original.key, saga: original.saga},
           returned: %{key: updated.key, saga: updated.saga}
         }}

      {:error, callback_error(reason, saga, original.key)}
    end
  end

  defp commit(saga, instance, config) do
    changes = Instance.changes(instance)

    if changes == %{state: %{}, context: %{}, status: nil} do
      {:ok, instance}
    else
      case Storage.commit(config.storage, instance, changes) do
        {:ok, persisted} ->
          emit_completion(persisted, saga, config)
          {:ok, persisted}

        {:error, :completed} ->
          ignored(:completed, saga, instance.key)

        {:error, reason} ->
          {:error, storage_error(reason, saga, instance.key, config)}
      end
    end
  end

  defp emit_completion(%Instance{status: :completed} = instance, saga, config) do
    :telemetry.execute(
      [:saga_weaver, :completion],
      %{system_time: System.system_time()},
      %{saga: saga, key: instance.key, storage: elem(config.storage, 0)}
    )
  end

  defp emit_completion(%Instance{}, _saga, _config), do: :ok

  defp ignored(reason, saga, key) do
    :telemetry.execute(
      [:saga_weaver, :ignored],
      %{system_time: System.system_time()},
      %{saga: saga, key: key, reason: reason}
    )

    {:ignored, reason}
  end

  defp storage_error(reason, saga, key, config) do
    Error.new(:storage, reason,
      metadata: %{saga: saga, key: key, storage: elem(config.storage, 0)}
    )
  end

  defp callback_error(reason, saga, key) do
    Error.new(:callback, reason, metadata: %{saga: saga, key: key})
  end

  defp result_type({:ok, _}), do: :ok
  defp result_type({:ignored, _}), do: :ignored
  defp result_type({:error, _}), do: :error
end
