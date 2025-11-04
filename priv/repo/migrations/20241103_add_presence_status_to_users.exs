defmodule ViralEngine.Repo.Migrations.AddPresenceStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:presence_status, :string, default: "offline")
      add(:last_seen_at, :utc_datetime)
    end
  end
end
