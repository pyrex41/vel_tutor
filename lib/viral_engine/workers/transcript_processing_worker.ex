defmodule ViralEngine.Workers.TranscriptProcessingWorker do
  @moduledoc """
  Oban worker for processing session transcripts asynchronously.

  Handles audio transcription and AI summarization in the background.
  """

  use Oban.Worker,
    queue: :transcripts,
    max_attempts: 3,
    priority: 1

  alias ViralEngine.TranscriptContext
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"transcript_id" => transcript_id, "audio_file_path" => audio_file_path}}) do
    Logger.info("Processing transcript #{transcript_id} with audio file: #{audio_file_path}")

    case TranscriptContext.process_audio_file(transcript_id, audio_file_path) do
      {:ok, transcript} ->
        Logger.info("Successfully processed transcript #{transcript_id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to process transcript #{transcript_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Enqueues a transcript processing job.
  """
  def enqueue(transcript_id, audio_file_path, opts \\ []) do
    %{
      transcript_id: transcript_id,
      audio_file_path: audio_file_path
    }
    |> __MODULE__.new(opts)
    |> Oban.insert()
  end
end
