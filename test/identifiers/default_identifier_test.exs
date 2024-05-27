defmodule SagaWeaver.Identifiers.DefaultIdentifierTest do
  use ExUnit.Case

  alias SagaWeaver.Identifiers.DefaultIdentifier
  alias SagaWeaver.Test.TestMessage
  alias SagaWeaver.Test.TestMessageFinal

  describe "unique_saga_id/3" do
    test "returns a unique id" do
      message = %SagaWeaver.Test.TestMessage{id: 1, uuid: UUID.uuid4(), atom_key: :test_key}
      entity_name = SagaWeaver.Test.TestSaga

      unique_saga_id_mapping = %{
        TestMessage => &%{id: &1.id, uuid: &1.uuid, atom_key: &1.atom_key}
      }

      assert unique_id =
               DefaultIdentifier.unique_saga_id(
                 message,
                 entity_name,
                 unique_saga_id_mapping
               )

      assert String.starts_with?(unique_id, "Elixir.SagaWeaver.Test.TestSaga:")
    end

    test "two separate messages have the same key" do
      uuid = UUID.uuid4()
      message = %SagaWeaver.Test.TestMessage{id: 1, uuid: uuid, atom_key: :test_key}

      second_message = %SagaWeaver.Test.TestMessageFinal{
        external_id: 1,
        external_uuid: uuid,
        external_atom_key: :test_key
      }

      entity_name = SagaWeaver.Test.TestSaga

      unique_saga_id_mapping = %{
        TestMessage => &%{id: &1.id, uuid: &1.uuid, atom_key: &1.atom_key},
        TestMessageFinal =>
          &%{
            id: &1.external_id,
            uuid: &1.external_uuid,
            atom_key: &1.external_atom_key
          }
      }

      assert first_unique_id =
               DefaultIdentifier.unique_saga_id(
                 message,
                 entity_name,
                 unique_saga_id_mapping
               )

      assert second_unique_id =
               DefaultIdentifier.unique_saga_id(
                 second_message,
                 entity_name,
                 unique_saga_id_mapping
               )

      assert first_unique_id == second_unique_id
    end
  end

  describe "get_mapped_saga_ids/2" do
    test "returns a mapped id" do
      message = %SagaWeaver.Test.TestMessage{id: 1, uuid: UUID.uuid4(), atom_key: :test_key}

      unique_saga_id_mapping = %{
        TestMessage => &%{id: &1.id}
      }

      assert %{:id => 1} = DefaultIdentifier.get_mapped_saga_ids(message, unique_saga_id_mapping)
    end
  end
end
