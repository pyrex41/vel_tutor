defmodule ViralEngine.Repo.Migrations.AddPhase3HotPathIndexes do
  use Ecto.Migration

  def change do
    # Critical indexes for TrustSafety duplicate detection queries
    # Used in check_duplicate_signup and check_duplicate_share
    create_if_not_exists index(:device_flags, [:inserted_at, :flag_type, :device_id],
      name: :device_flags_duplicate_detection_idx
    )

    create_if_not_exists index(:device_flags, [:ip_address, :inserted_at],
      name: :device_flags_ip_time_idx
    )

    # Index for fraud scoring queries
    create_if_not_exists index(:device_flags, [:device_id, :blocked],
      name: :device_flags_device_blocked_idx
    )

    # Index for session intelligence pipeline queries
    create_if_not_exists index(:tutoring_sessions, [:student_id, :started_at],
      name: :tutoring_sessions_student_time_idx
    )

    create_if_not_exists index(:tutoring_sessions, [:tutor_id, :ended_at],
      name: :tutoring_sessions_tutor_time_idx
    )

    # Unique constraint for weekly recaps (prevents duplicate generation)
    create_if_not_exists unique_index(:weekly_recaps, [:parent_id, :week_start],
      name: :weekly_recaps_parent_week_unique_idx
    )

    # Index for recap queries by week
    create_if_not_exists index(:weekly_recaps, [:week_start, :inserted_at],
      name: :weekly_recaps_week_time_idx
    )
  end
end
