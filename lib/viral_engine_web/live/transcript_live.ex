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

  # Note: Helper functions for UI rendering have been removed until
  # a render/1 function or .heex template is implemented.
  # Functions included: status_badge_class/1, status_text/1, sentiment_indicator/1,
  # sentiment_color/1, format_duration/1, format_timestamp/1, session_type_name/1,
  # confidence_percentage/1, truncate_text/2
end
