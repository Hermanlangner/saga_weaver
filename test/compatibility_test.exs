defmodule SagaWeaver.CompatibilityTest do
  use ExUnit.Case, async: true

  alias SagaWeaver.Compatibility
  alias SagaWeaver.Identifiers.DefaultIdentifier

  defmodule Message do
    defstruct [:id]
  end

  defmodule LegacySaga do
    def entity_name, do: "legacy_saga"
    def identity_key_mapping, do: %{Message => &%{id: &1.id}}
  end

  test "derives the exact v1 key" do
    message = %Message{id: 123}

    expected =
      DefaultIdentifier.unique_saga_id(
        message,
        LegacySaga.entity_name(),
        LegacySaga.identity_key_mapping()
      )

    assert Compatibility.v1_key(LegacySaga, message) == {:ok, expected}
  end

  test "reports a missing mapping" do
    assert Compatibility.v1_key(LegacySaga, %URI{}) ==
             {:error, {:missing_identity_mapping, URI}}
  end

  test "rejects invalid messages" do
    assert Compatibility.v1_key(LegacySaga, %{}) == {:error, {:invalid_message, %{}}}
  end
end
