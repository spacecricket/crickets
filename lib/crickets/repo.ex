defmodule Crickets.Repo do
  use Ecto.Repo,
    otp_app: :crickets,
    adapter: Ecto.Adapters.Postgres
end
