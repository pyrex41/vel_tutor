defmodule ViralEngine.Repo.Migrations.AddPresenceStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:presence_status, :string, default: "offline")
      add(:last_seen_at, :utc_datetime)
      add(:presence_opt_out, :boolean, default: false)
    end
  end
end
