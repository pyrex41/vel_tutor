defmodule ViralEngine.Repo.Migrations.AddLeftAtToPresences do
  use Ecto.Migration

  def change do
    alter table(:presences) do
      add(:left_at, :utc_datetime)
    end
  end
end
