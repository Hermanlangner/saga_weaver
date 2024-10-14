defmodule SagaWeaver.Test.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :saga_weaver,
    adapter: Ecto.Adapters.Postgres
end
