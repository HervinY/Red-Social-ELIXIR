defmodule RedSocial.Repo do
  use Ecto.Repo,
    otp_app: :red_social,
    adapter: Ecto.Adapters.SQLite3
end
