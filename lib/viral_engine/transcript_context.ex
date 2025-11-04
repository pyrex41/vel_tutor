defmodule ViralEngine.TranscriptContext do
  @moduledoc """
  Context module for managing session transcripts.

  Handles audio upload, transcription via external services (OpenAI Whisper),
  and AI summarization with key point extraction.
  """

  import Ecto.Query
  alias ViralEngine.{Repo, SessionTranscript, AIClient}
  require Logger

  @transcription_provider Application.compile_env(:viral_engine, :transcription_provider, "openai")
  @max_audio_size_mb 25  # OpenAI Whisper limit

  @doc """
  Creates a new session transcript record.
  """
  def create_transcript(attrs) do
    %SessionTranscript{}
    |> SessionTranscript.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a transcript by ID.
  """
  def get_transcript(transcript_id) do
    Repo.get(SessionTranscript, transcript_id)
  end

  @doc """
  Gets transcript by session.
  """
  def get_session_transcript(session_id, session_type) do
    from(t in SessionTranscript,
      where: t.session_id == ^session_id and t.session_type == ^session_type,
      order_by: [desc: t.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Lists user's transcripts.
  """
  def list_user_transcripts(user_id, opts \\ []) do
    limit = opts[:limit] || 20

    query = from(t in SessionTranscript,
      where: t.user_id == ^user_id,
      order_by: [desc: t.inserted_at],
      limit: ^limit
    )

    query = if opts[:status] do
      from(t in query, where: t.processing_status == ^opts[:status])
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Processes an audio file: transcribes and summarizes.

  This is typically called asynchronously via Oban worker.
  """
  def process_audio_file(transcript_id, audio_file_path) do
    transcript = get_transcript(transcript_id)

    if !transcript do
      {:error, :not_found}
    else
      # Mark as transcribing
      {:ok, transcript} = Repo.update(SessionTranscript.mark_transcribing(transcript))

      # Step 1: Transcribe audio
      case transcribe_audio(audio_file_path, transcript.language) do
        {:ok, transcription_result} ->
          # Update transcript text and segments
          {:ok, transcript} = Repo.update(SessionTranscript.changeset(transcript, %{
            transcript_text: transcription_result.text,
            transcript_segments: transcription_result.segments || [],
            confidence_score: transcription_result.confidence,
            transcription_provider: @transcription_provider
          }))

          # Mark as summarizing
          {:ok, transcript} = Repo.update(SessionTranscript.mark_summarizing(transcript))

          # Step 2: Generate AI summary
          case summarize_transcript(transcription_result.text, transcript.session_type) do
            {:ok, summary_result} ->
              # Update summary and key points
              {:ok, transcript} = Repo.update(SessionTranscript.changeset(transcript, %{
                ai_summary: summary_result.summary,
                key_points: summary_result.key_points,
                sentiment_score: summary_result.sentiment
              }))

              # Mark as completed
              {:ok, completed_transcript} = Repo.update(SessionTranscript.mark_completed(transcript))

              Logger.info("Transcript #{transcript_id} processed successfully")

              # Broadcast completion event
              Phoenix.PubSub.broadcast(
                ViralEngine.PubSub,
                "user:#{transcript.user_id}:transcripts",
                {:transcript_completed, %{transcript: completed_transcript}}
              )

              {:ok, completed_transcript}

            {:error, reason} ->
              Logger.error("Failed to summarize transcript #{transcript_id}: #{inspect(reason)}")
              {:ok, failed} = Repo.update(SessionTranscript.mark_failed(transcript, "Summarization failed: #{inspect(reason)}"))
              {:error, reason}
          end

        {:error, reason} ->
          Logger.error("Failed to transcribe audio for transcript #{transcript_id}: #{inspect(reason)}")
          {:ok, failed} = Repo.update(SessionTranscript.mark_failed(transcript, "Transcription failed: #{inspect(reason)}"))
          {:error, reason}
      end
    end
  end

  @doc """
  Uploads audio file to storage (S3 or local).

  Returns {:ok, url} or {:error, reason}.
  """
  def upload_audio_file(file_path, user_id, session_id) do
    # In production, this would upload to S3 or similar
    # For now, simulate with a local path
    filename = "#{user_id}_#{session_id}_#{System.system_time(:second)}.webm"
    storage_path = "/uploads/audio/#{filename}"

    # Simulate upload
    Logger.info("Uploading audio file: #{file_path} -> #{storage_path}")

    # In production:
    # ExAws.S3.put_object(bucket, storage_path, File.read!(file_path))
    # |> ExAws.request()

    {:ok, storage_path}
  end

  # Private functions

  defp transcribe_audio(audio_file_path, language) do
    case @transcription_provider do
      "openai" ->
        transcribe_with_openai(audio_file_path, language)

      "google" ->
        transcribe_with_google(audio_file_path, language)

      "assembly" ->
        transcribe_with_assembly(audio_file_path, language)

      _ ->
        {:error, :unknown_provider}
    end
  end

  defp transcribe_with_openai(audio_file_path, language) do
    # OpenAI Whisper API transcription
    Logger.info("Transcribing audio with OpenAI Whisper: #{audio_file_path}")

    # Check file size
    file_size_mb = File.stat!(audio_file_path).size / (1024 * 1024)
    if file_size_mb > @max_audio_size_mb do
      {:error, :file_too_large}
    else
      # In production, call OpenAI Whisper API
      # For now, simulate transcription
      simulate_transcription(audio_file_path)

      # Real implementation:
      # AIClient.transcribe_audio(audio_file_path, language)
    end
  end

  defp transcribe_with_google(_audio_file_path, _language) do
    # Google Speech-to-Text API
    {:error, :not_implemented}
  end

  defp transcribe_with_assembly(_audio_file_path, _language) do
    # AssemblyAI API
    {:error, :not_implemented}
  end

  defp simulate_transcription(_audio_file_path) do
    # Simulated transcription response
    {:ok, %{
      text: """
      In this practice session, I worked through several math problems.
      First, I solved a quadratic equation using the quadratic formula.
      Then I practiced factoring polynomials and graphing linear equations.
      I found the factoring problems challenging but managed to complete them all.
      Overall, I feel more confident with these concepts now.
      """,
      segments: [
        %{start: 0.0, end: 3.5, text: "In this practice session, I worked through several math problems."},
        %{start: 3.5, end: 7.2, text: "First, I solved a quadratic equation using the quadratic formula."},
        %{start: 7.2, end: 11.8, text: "Then I practiced factoring polynomials and graphing linear equations."},
        %{start: 11.8, end: 16.5, text: "I found the factoring problems challenging but managed to complete them all."},
        %{start: 16.5, end: 20.0, text: "Overall, I feel more confident with these concepts now."}
      ],
      confidence: 0.92,
      language: "en"
    }}
  end

  defp summarize_transcript(transcript_text, session_type) do
    Logger.info("Generating AI summary for #{session_type} transcript")

    # Build prompt based on session type
    prompt = build_summary_prompt(transcript_text, session_type)

    # In production, call AI service
    # For now, simulate AI summary
    simulate_ai_summary(transcript_text)

    # Real implementation:
    # AIClient.generate_summary(prompt)
  end

  defp build_summary_prompt(transcript_text, session_type) do
    context = case session_type do
      "practice_session" ->
        "This is a transcript from a student's practice session where they worked through educational exercises."

      "diagnostic_assessment" ->
        "This is a transcript from a student's diagnostic assessment where they demonstrated their knowledge."

      _ ->
        "This is a transcript from an educational session."
    end

    """
    #{context}

    Please provide:
    1. A concise summary (2-3 sentences) of what the student accomplished
    2. 3-5 key points or takeaways from the session
    3. Overall sentiment analysis (positive/neutral/negative)

    Transcript:
    #{transcript_text}

    Format your response as JSON:
    {
      "summary": "...",
      "key_points": ["...", "...", "..."],
      "sentiment": 0.8
    }
    """
  end

  defp simulate_ai_summary(_transcript_text) do
    # Simulated AI summary
    {:ok, %{
      summary: "The student demonstrated strong problem-solving skills while working through quadratic equations, factoring, and linear graphing. They encountered some challenges with polynomial factoring but persevered and completed all exercises. Overall confidence increased by the end of the session.",
      key_points: [
        "Successfully applied quadratic formula",
        "Practiced polynomial factoring techniques",
        "Completed all linear graphing exercises",
        "Showed perseverance through challenging problems",
        "Increased confidence in algebraic concepts"
      ],
      sentiment: 0.75  # Positive sentiment
    }}
  end
end
