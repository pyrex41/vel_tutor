defmodule ViralEngine.Repo.Migrations.CreateSessionTranscripts do
  use Ecto.Migration

  def change do
    create table(:session_transcripts) do
      add :session_id, :integer, null: false
      add :session_type, :string, null: false
      add :user_id, :integer, null: false

      add :audio_url, :string
      add :audio_duration, :integer
      add :audio_format, :string, default: "webm"

      add :transcript_text, :text
      add :transcript_segments, {:array, :map}, default: []
      add :language, :string, default: "en-US"

      add :ai_summary, :text
      add :key_points, {:array, :string}, default: []
      add :sentiment_score, :float
      add :confidence_score, :float

      add :processing_status, :string, default: "pending", null: false
      add :error_message, :text

      add :metadata, :map, default: "{}"
      add :processed_at, :utc_datetime
      add :transcription_provider, :string

      timestamps()
    end

    # Query indexes
    create index(:session_transcripts, [:user_id])
    create index(:session_transcripts, [:session_id, :session_type])
    create index(:session_transcripts, [:processing_status])
    create index(:session_transcripts, [:processed_at])

    # Unique constraint: one transcript per session
    create unique_index(:session_transcripts, [:session_id, :session_type])
  end
end
