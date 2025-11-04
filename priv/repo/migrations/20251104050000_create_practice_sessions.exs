defmodule ViralEngine.Repo.Migrations.CreatePracticeSessions do
  use Ecto.Migration

  def change do
    create table(:practice_sessions) do
      add :user_id, :integer, null: false
      add :session_type, :string, null: false
      add :subject, :string, null: false
      add :current_step, :integer, default: 1
      add :total_steps, :integer
      add :timer_seconds, :integer, default: 0
      add :paused, :boolean, default: false
      add :completed, :boolean, default: false
      add :score, :integer
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:practice_sessions, [:user_id])
    create index(:practice_sessions, [:user_id, :completed])
    create index(:practice_sessions, [:session_type])
  end
end
