defmodule SagaWeaver.Error do
  @moduledoc """
  A structured error returned by SagaWeaver's public API.

  The `kind` classifies the failed boundary while `reason` retains the original
  adapter, callback, routing, or configuration error.
  """

  @type kind :: :config | :routing | :storage | :callback | :conflict | :encoding | :unknown

  @type t :: %__MODULE__{
          kind: kind(),
          reason: term(),
          message: String.t(),
          metadata: map()
        }

  defexception [:kind, :reason, :message, metadata: %{}]

  @doc """
  Builds a structured SagaWeaver error.
  """
  @spec new(kind(), term(), keyword()) :: t()
  def new(kind, reason, opts \\ []) do
    %__MODULE__{
      kind: kind,
      reason: reason,
      message: Keyword.get(opts, :message, default_message(kind, reason)),
      metadata: opts |> Keyword.get(:metadata, %{}) |> Map.new()
    }
  end

  @doc """
  Preserves an existing SagaWeaver error or wraps another reason.
  """
  @spec wrap(kind(), term(), keyword()) :: t()
  def wrap(kind, reason, opts \\ [])

  def wrap(_kind, %__MODULE__{} = error, _opts), do: error
  def wrap(kind, reason, opts), do: new(kind, reason, opts)

  defp default_message(kind, reason) do
    "SagaWeaver #{kind} error: #{inspect(reason)}"
  end
end
