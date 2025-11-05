defmodule ViralEngine.Repo.Migrations.AddPresenceOptOutToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:presence_opt_out, :boolean, default: false)
    end
  end
end
