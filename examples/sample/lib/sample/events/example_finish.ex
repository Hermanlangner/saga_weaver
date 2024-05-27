defmodule ExampleFinish do
  @behaviour SagaWeaver.Message

  defstruct [:id, :name]

  @impl true
  def name do
    __MODULE__
  end

  @impl true
  def content_type do
    __MODULE__
  end
end
