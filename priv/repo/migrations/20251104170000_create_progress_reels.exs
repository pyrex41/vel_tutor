defmodule ViralEngine.Repo.Migrations.CreateProgressReels do
  use Ecto.Migration

  def change do
    create table(:progress_reels) do
      add :student_id, :integer, null: false
      add :reel_type, :string, null: false
      add :reel_token, :string, null: false

      add :title, :string, null: false
      add :subtitle, :string

      add :trigger_event, :map, default: "{}"
      add :reel_data, :map, default: "{}"

      add :media_url, :string
      add :media_type, :string, default: "image"

      add :generation_status, :string, default: "pending", null: false

      add :view_count, :integer, default: 0
      add :share_count, :integer, default: 0

      add :is_shared_with_parent, :boolean, default: false
      add :parent_shared_at, :utc_datetime

      add :expires_at, :utc_datetime
      add :metadata, :map, default: "{}"

      timestamps()
    end

    # Unique reel token
    create unique_index(:progress_reels, [:reel_token])

    # Query indexes
    create index(:progress_reels, [:student_id])
    create index(:progress_reels, [:reel_type])
    create index(:progress_reels, [:generation_status])
    create index(:progress_reels, [:created_at])
    create index(:progress_reels, [:expires_at])
  end
end
