defmodule ViralEngine.Repo.Migrations.Phase2Schema do
  use Ecto.Migration

  def change do
    # Challenge Decks for Buddy Challenge loop
    create table(:challenge_decks) do
      add(:type, :string, null: false)
      add(:skill, :string)
      # JSON array of question objects
      add(:questions, :map)
      add(:participant_count, :integer, default: 0)
      add(:completion_count, :integer, default: 0)
      add(:expires_at, :utc_datetime)
      timestamps()
    end

    create(index(:challenge_decks, [:skill]))
    create(index(:challenge_decks, [:expires_at]))

    # Challenge Sessions for tracking participation
    create table(:challenge_sessions) do
      add(:deck_id, references(:challenge_decks, on_delete: :delete_all))
      add(:user_id, :integer, null: false)
      add(:referrer_id, :integer)
      add(:link_id, references(:attribution_links, on_delete: :nilify_all))
      add(:score, :integer)
      add(:completed_at, :utc_datetime)
      timestamps()
    end

    create(index(:challenge_sessions, [:deck_id]))
    create(index(:challenge_sessions, [:user_id]))
    create(index(:challenge_sessions, [:referrer_id]))
  end
end
