defmodule ViralEngine.Repo.Migrations.AddHealthScoreIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # Index for parent share opt-out rate queries
    create_if_not_exists(
      index(
        :parent_shares,
        [:inserted_at, :viewed],
        concurrently: true,
        name: :idx_parent_shares_opt_out_rate
      )
    )

    # Index for attribution link opt-out rate queries
    create_if_not_exists(
      index(
        :attribution_links,
        [:inserted_at, :click_count],
        concurrently: true,
        name: :idx_attribution_links_opt_out_rate
      )
    )

    # Index for study session participant queries
    create_if_not_exists(
      index(
        :study_sessions,
        [:inserted_at],
        concurrently: true,
        name: :idx_study_sessions_inserted_at
      )
    )

    # Index for progress reel COPPA compliance queries
    create_if_not_exists(
      index(
        :progress_reels,
        [:inserted_at],
        concurrently: true,
        name: :idx_progress_reels_inserted_at
      )
    )
  end
end
