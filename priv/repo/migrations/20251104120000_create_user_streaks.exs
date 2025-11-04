defmodule ViralEngine.Repo.Migrations.CreateUserStreaks do
  use Ecto.Migration

  def change do
    create table(:user_streaks) do
      add :user_id, :integer, null: false
      add :current_streak, :integer, default: 0
      add :longest_streak, :integer, default: 0
      add :last_activity_date, :date
      add :next_deadline, :utc_datetime
      add :streak_at_risk, :boolean, default: false
      add :rescue_sent, :boolean, default: false
      add :rescue_sent_at, :utc_datetime

      timestamps()
    end

    # Unique user constraint
    create unique_index(:user_streaks, [:user_id])

    # Query indexes
    create index(:user_streaks, [:streak_at_risk])
    create index(:user_streaks, [:next_deadline])
    create index(:user_streaks, [:current_streak])

    # At-risk detection query
    create index(:user_streaks, [:next_deadline, :rescue_sent])
  end
end
