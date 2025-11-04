defmodule ViralEngine.SessionTranscript do
  @moduledoc """
  Schema for storing session transcripts.

  Tracks audio recordings, transcriptions, and AI-generated summaries
  for practice sessions and diagnostic assessments.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "session_transcripts" do
    field(:session_id, :integer)
    field(:session_type, :string)  # practice_session, diagnostic_assessment
    field(:user_id, :integer)

    field(:audio_url, :string)      # S3/storage URL for audio file
    field(:audio_duration, :integer) # Duration in seconds
    field(:audio_format, :string, default: "webm")

    field(:transcript_text, :string)
    field(:transcript_segments, {:array, :map}, default: [])  # Timestamped segments
    field(:language, :string, default: "en-US")

    field(:ai_summary, :string)
    field(:key_points, {:array, :string}, default: [])
    field(:sentiment_score, :float)  # -1.0 to 1.0
    field(:confidence_score, :float) # 0.0 to 1.0

    field(:processing_status, :string, default: "pending")
    # pending, transcribing, summarizing, completed, failed

    field(:error_message, :string)
    field(:metadata, :map, default: %{})

    field(:processed_at, :utc_datetime)
    field(:transcription_provider, :string) # openai, google, assembly

    timestamps()
  end

  def changeset(transcript, attrs) do
    transcript
    |> cast(attrs, [
      :session_id,
      :session_type,
      :user_id,
      :audio_url,
      :audio_duration,
      :audio_format,
      :transcript_text,
      :transcript_segments,
      :language,
      :ai_summary,
      :key_points,
      :sentiment_score,
      :confidence_score,
      :processing_status,
      :error_message,
      :metadata,
      :processed_at,
      :transcription_provider
    ])
    |> validate_required([:session_id, :session_type, :user_id])
    |> validate_inclusion(:session_type, ["practice_session", "diagnostic_assessment"])
    |> validate_inclusion(:processing_status, ["pending", "transcribing", "summarizing", "completed", "failed"])
  end

  @doc """
  Marks transcript as being transcribed.
  """
  def mark_transcribing(transcript) do
    changeset(transcript, %{processing_status: "transcribing"})
  end

  @doc """
  Marks transcript as being summarized.
  """
  def mark_summarizing(transcript) do
    changeset(transcript, %{processing_status: "summarizing"})
  end

  @doc """
  Marks transcript as completed.
  """
  def mark_completed(transcript) do
    changeset(transcript, %{
      processing_status: "completed",
      processed_at: DateTime.utc_now()
    })
  end

  @doc """
  Marks transcript as failed with error.
  """
  def mark_failed(transcript, error_message) do
    changeset(transcript, %{
      processing_status: "failed",
      error_message: error_message,
      processed_at: DateTime.utc_now()
    })
  end
end
