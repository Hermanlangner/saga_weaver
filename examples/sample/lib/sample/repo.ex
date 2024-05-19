defmodule Sample.Repo do
  use Ecto.Repo,
    otp_app: :sample,
    adapter: Ecto.Adapters.Postgres
end
