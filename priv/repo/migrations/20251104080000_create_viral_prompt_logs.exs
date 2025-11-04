defmodule ViralEngine.Repo.Migrations.CreateViralPromptLogs do
  use Ecto.Migration

  def change do
    create table(:viral_prompt_logs) do
      add :user_id, :integer, null: false
      add :loop_type, :string, null: false
      add :variant, :string, null: false
      add :prompt_text, :text, null: false
      add :event_data, :map, default: "{}"
      add :shown_at, :utc_datetime, null: false
      add :clicked, :boolean, default: false
      add :clicked_at, :utc_datetime
      add :converted, :boolean, default: false
      add :converted_at, :utc_datetime

      timestamps()
    end

    # Index for throttling queries
    create index(:viral_prompt_logs, [:user_id, :inserted_at])

    # Index for loop-specific cooldown queries
    create index(:viral_prompt_logs, [:user_id, :loop_type, :inserted_at])

    # Index for A/B test analysis
    create index(:viral_prompt_logs, [:loop_type, :variant])

    # Index for conversion tracking
    create index(:viral_prompt_logs, [:loop_type, :variant, :converted])
  end
end
