defmodule SagaWeaver.ConfigTest do
  use ExUnit.Case, async: false

  alias SagaWeaver.{Config, Instance}
  alias SagaWeaver.Storage.Memory

  defmodule Facade do
    use SagaWeaver, otp_app: :saga_weaver
  end

  defmodule ConfiguredSaga do
    use SagaWeaver.Saga

    @impl true
    def route(%{id: id}), do: {:start, "configured:#{id}"}

    @impl true
    def handle(instance, _message), do: {:ok, Instance.put_state(instance, :handled, true)}
  end

  setup do
    original = Application.get_env(:saga_weaver, Facade)

    on_exit(fn ->
      if original do
        Application.put_env(:saga_weaver, Facade, original)
      else
        Application.delete_env(:saga_weaver, Facade)
      end
    end)

    :ok
  end

  test "validates an application-owned facade configuration" do
    pid = start_supervised!(Memory)
    Application.put_env(:saga_weaver, Facade, storage: {Memory, name: pid})

    assert %Config{facade: Facade, storage: {Memory, opts}} = Facade.config()
    assert opts[:name] == pid
    assert opts[:max_retries] == 5

    assert {:ok, %Instance{state: %{"handled" => true}}} =
             Facade.handle(ConfiguredSaga, %{id: 1})

    assert {:ok, %Instance{key: "configured:1"}} =
             Facade.fetch(ConfiguredSaga, "configured:1")
  end

  test "returns validation errors before calling storage" do
    assert {:error, {:missing_option, :connection}} =
             Config.fetch(:saga_weaver, Facade,
               storage: {SagaWeaver.Storage.Redis, namespace: "test"}
             )
  end
end
