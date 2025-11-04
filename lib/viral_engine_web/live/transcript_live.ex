defmodule ViralEngineWeb.TranscriptLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.TranscriptContext
  # alias ViralEngine.SessionTranscript  # Unused - commented for future use
  require Logger

  @impl true
  def mount(%{"id" => transcript_id}, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    transcript = TranscriptContext.get_transcript(transcript_id)

    if transcript && transcript.user_id == user.id do
      if connected?(socket) do
        # Subscribe to transcript updates
        Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:transcripts")
      end

      socket =
        socket
        |> assign(:user, user)
        |> assign(:user_id, user.id)
        |> assign(:transcript, transcript)
        |> assign(:playing_segment, nil)
        |> assign(:show_full_transcript, false)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Transcript not found")
       |> redirect(to: "/dashboard")}
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to transcript updates
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:transcripts")
    end

    # List user's transcripts
    transcripts = TranscriptContext.list_user_transcripts(user.id, limit: 20)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:transcripts, transcripts)
      |> assign(:selected_transcript, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_transcript", %{"transcript_id" => transcript_id_str}, socket) do
    transcript_id = String.to_integer(transcript_id_str)
    transcript = TranscriptContext.get_transcript(transcript_id)

    {:noreply, assign(socket, :selected_transcript, transcript)}
  end

  @impl true
  def handle_event("toggle_full_transcript", _params, socket) do
    {:noreply, assign(socket, :show_full_transcript, !socket.assigns.show_full_transcript)}
  end

  @impl true
  def handle_event("play_segment", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    {:noreply, assign(socket, :playing_segment, index)}
  end

  @impl true
  def handle_event("copy_transcript", _params, socket) do
    {:noreply, put_flash(socket, :success, "Transcript copied to clipboard!")}
  end

  @impl true
  def handle_event("download_transcript", _params, socket) do
    # Would trigger download in production
    {:noreply, put_flash(socket, :info, "Downloading transcript...")}
  end

  @impl true
  def handle_info({:transcript_completed, %{transcript: updated_transcript}}, socket) do
    # Update transcript if it's the one being viewed
    socket = if socket.assigns[:transcript] && socket.assigns.transcript.id == updated_transcript.id do
      assign(socket, :transcript, updated_transcript)
    else
      # Refresh list if viewing list
      if socket.assigns[:transcripts] do
        transcripts = TranscriptContext.list_user_transcripts(socket.assigns.user_id, limit: 20)
        assign(socket, :transcripts, transcripts)
      else
        socket
      end
    end

    {:noreply,
     socket
     |> put_flash(:success, "✨ Transcript processing completed!")}
  end

  # Helper functions

  defp status_badge_class(status) do
    case status do
      "pending" -> "bg-yellow-100 text-yellow-800"
      "transcribing" -> "bg-blue-100 text-blue-800 animate-pulse"
      "summarizing" -> "bg-purple-100 text-purple-800 animate-pulse"
      "completed" -> "bg-green-100 text-green-800"
      "failed" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp status_text(status) do
    case status do
      "pending" -> "Pending"
      "transcribing" -> "Transcribing..."
      "summarizing" -> "Generating Summary..."
      "completed" -> "Completed"
      "failed" -> "Failed"
      _ -> "Unknown"
    end
  end

  defp sentiment_indicator(score) when is_float(score) do
    cond do
      score >= 0.5 -> "😊 Positive"
      score >= 0.0 -> "😐 Neutral"
      true -> "😟 Needs Support"
    end
  end
  defp sentiment_indicator(_), do: "Unknown"

  defp sentiment_color(score) when is_float(score) do
    cond do
      score >= 0.5 -> "text-green-600"
      score >= 0.0 -> "text-yellow-600"
      true -> "text-red-600"
    end
  end
  defp sentiment_color(_), do: "text-gray-600"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end
  defp format_duration(_), do: "0:00"

  defp format_timestamp(seconds) when is_float(seconds) do
    format_duration(round(seconds))
  end
  defp format_timestamp(_), do: "0:00"

  defp session_type_name(type) do
    case type do
      "practice_session" -> "Practice Session"
      "diagnostic_assessment" -> "Diagnostic Assessment"
      _ -> "Session"
    end
  end

  defp confidence_percentage(score) when is_float(score) do
    "#{round(score * 100)}%"
  end
  defp confidence_percentage(_), do: "N/A"

  defp truncate_text(text, max_length \\ 150) when is_binary(text) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end
  defp truncate_text(_, _), do: ""
end
