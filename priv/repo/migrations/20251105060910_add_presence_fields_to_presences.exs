defmodule ViralEngine.Repo.Migrations.AddPresenceFieldsToPresences do
  use Ecto.Migration

  def change do
    alter table(:presences) do
      add(:subject_id, :integer)
      add(:session_id, :string)
      add(:status, :string, default: "online")
      add(:current_activity, :string)
      add(:metadata, :map, default: %{})
      add(:last_seen_at, :utc_datetime)
    end

    create(index(:presences, [:subject_id]))
    create(index(:presences, [:last_seen_at]))
    create(unique_index(:presences, [:session_id], where: "session_id IS NOT NULL"))
  end
end
