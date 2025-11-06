defmodule ViralEngine.Repo.Migrations.Phase3Schema do
  use Ecto.Migration

  def change do
    # Parental Consents for COPPA compliance
    create_if_not_exists table(:parental_consents) do
      add :user_id, :integer, null: false
      add :parent_email, :string, null: false
      add :consent_given, :boolean, default: false, null: false
      add :consent_date, :utc_datetime
      add :ip_address, :string
      add :consent_text, :text
      add :withdrawn_at, :utc_datetime
      timestamps()
    end

    create_if_not_exists index(:parental_consents, [:user_id])
    create_if_not_exists index(:parental_consents, [:parent_email])
    create_if_not_exists index(:parental_consents, [:consent_given])

    # Device Flags for fraud detection and bot prevention
    create_if_not_exists table(:device_flags) do
      add :device_id, :string, null: false
      add :ip_address, :string, null: false
      add :user_agent, :text
      add :fingerprint, :string
      add :flag_type, :string, null: false
      add :flag_reason, :text
      add :risk_score, :float, default: 0.0
      add :blocked, :boolean, default: false
      add :blocked_at, :utc_datetime
      add :cleared_at, :utc_datetime
      timestamps()
    end

    create_if_not_exists index(:device_flags, [:device_id])
    create_if_not_exists index(:device_flags, [:ip_address])
    create_if_not_exists index(:device_flags, [:fingerprint])
    create_if_not_exists index(:device_flags, [:flag_type])
    create_if_not_exists index(:device_flags, [:blocked])
    create_if_not_exists index(:device_flags, [:risk_score])

    # Tutoring Sessions for session intelligence pipeline
    create_if_not_exists table(:tutoring_sessions) do
      add :student_id, :integer, null: false
      add :tutor_id, :integer, null: false
      add :subject, :string
      add :topic, :string
      add :duration_minutes, :integer
      add :rating, :integer
      add :feedback, :text
      add :transcript_url, :string
      add :transcript_text, :text
      add :summary, :text
      add :ai_summary, :text
      add :student_actions, :map
      add :tutor_actions, :map
      add :parent_actions, :map
      add :processed, :boolean, default: false
      add :processed_at, :utc_datetime
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime
      timestamps()
    end

    create_if_not_exists index(:tutoring_sessions, [:student_id])
    create_if_not_exists index(:tutoring_sessions, [:tutor_id])
    create_if_not_exists index(:tutoring_sessions, [:subject])
    create_if_not_exists index(:tutoring_sessions, [:rating])
    create_if_not_exists index(:tutoring_sessions, [:processed])
    create_if_not_exists index(:tutoring_sessions, [:started_at])
    create_if_not_exists index(:tutoring_sessions, [:ended_at])

    # Weekly Recaps for Proud Parent loop
    create_if_not_exists table(:weekly_recaps) do
      add :parent_id, :integer, null: false
      add :student_id, :integer, null: false
      add :week_start, :date, null: false
      add :week_end, :date, null: false
      add :session_count, :integer, default: 0
      add :total_minutes, :integer, default: 0
      add :skills_practiced, {:array, :string}, default: []
      add :improvements, :map
      add :highlights, :text
      add :progress_reel_url, :string
      add :shared, :boolean, default: false
      add :shared_at, :utc_datetime
      add :share_count, :integer, default: 0
      timestamps()
    end

    create_if_not_exists index(:weekly_recaps, [:parent_id])
    create_if_not_exists index(:weekly_recaps, [:student_id])
    create_if_not_exists index(:weekly_recaps, [:week_start])
    create_if_not_exists index(:weekly_recaps, [:shared])
    create_if_not_exists index(:weekly_recaps, [:inserted_at])

    # Achievements for gamification and viral loops
    create_if_not_exists table(:achievements) do
      add :user_id, :integer, null: false
      add :achievement_type, :string, null: false
      add :achievement_name, :string, null: false
      add :description, :text
      add :icon_url, :string
      add :points, :integer, default: 0
      add :tier, :string
      add :unlocked_at, :utc_datetime
      add :shared, :boolean, default: false
      add :shared_at, :utc_datetime
      add :metadata, :map
      timestamps()
    end

    create_if_not_exists index(:achievements, [:user_id])
    create_if_not_exists index(:achievements, [:achievement_type])
    create_if_not_exists index(:achievements, [:unlocked_at])
    create_if_not_exists index(:achievements, [:shared])
  end
end
