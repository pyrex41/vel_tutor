defmodule ViralEngine.Repo do
  use Ecto.Repo,
    otp_app: :viral_engine,
    adapter: Ecto.Adapters.Postgres
end
