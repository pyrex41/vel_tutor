defmodule ViralEngine.Repo.Migrations.AddJoinedAtToPresences do
  use Ecto.Migration

  def change do
    alter table(:presences) do
      add(:joined_at, :utc_datetime)
    end
  end
end
