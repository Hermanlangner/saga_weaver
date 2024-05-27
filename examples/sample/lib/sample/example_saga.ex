defmodule ExampleSaga do
  @moduledoc """
  ExampleSaga is a sample Saga that is used to demonstrate how to use SagaWeaver.
  """

  @impl true
  def entity_name() do
    __MODULE__
  end

  @impl true
  def started_by() do
    [ExampleStart]
  end

  @impl true
  def identity_key_mapping do
    %{
      ExampleStart => &%{id: &1.id},
      ExampleFinish => &%{id: &1.id}
    }
  end

  @impl true
  def handle_event(saga, %ExampleStart{} = event) do
    # Handle ExampleStart and update saga state
    require IEx; IEx.pry
    {:ok, saga}
  end

  @impl true
  def handle_event(saga, %ExampleFinish{} = event) do
    # Handle ExampleFinish and mark saga as completed
    require IEx; IEx.pry
    updated_saga = %{saga | marked_as_completed: true}
    {:ok, updated_saga}
  end

  @impl true
  def handle_event(_, _), do: {:error, "Event not recognized"}
end
