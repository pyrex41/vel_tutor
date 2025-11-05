defmodule ViralEngine.Repo.Migrations.CreatePrepPacks do
  use Ecto.Migration

  def change do
    create table(:prep_packs) do
      add(:student_id, :integer, null: false)
      add(:pack_token, :string, null: false)
      add(:pack_name, :string, null: false)

      add(:subject, :string, null: false)
      add(:grade_level, :integer)
      add(:target_topics, {:array, :string}, default: [])

      add(:pack_type, :string, default: "practice_prep", null: false)
      add(:resources, :map, default: "{}")
      add(:ai_recommendations, :text)
      add(:estimated_time_minutes, :integer, default: 30)

      add(:status, :string, default: "generated", null: false)
      add(:share_count, :integer, default: 0)
      add(:view_count, :integer, default: 0)

      add(:expires_at, :utc_datetime)
      add(:metadata, :map, default: "{}")

      timestamps()
    end

    # Unique pack token
    create(unique_index(:prep_packs, [:pack_token]))

    # Query indexes
    create(index(:prep_packs, [:student_id]))
    create(index(:prep_packs, [:subject]))
    create(index(:prep_packs, [:status]))
    create(index(:prep_packs, [:inserted_at]))
    create(index(:prep_packs, [:expires_at]))
  end
end
