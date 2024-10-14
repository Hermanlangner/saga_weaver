defmodule SagaWeaver.Behaviours.Message do
  @moduledoc false
  @callback name() :: atom()
  @callback content_type() :: atom()
end
