defmodule ExSaga.Behaviours.Event do
  @callback name() :: atom()
  @callback content_type() :: atom()
end
