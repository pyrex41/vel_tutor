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
      |> assign(:transcript, nil)
      |> assign(:selected_transcript, nil)
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
  def handle_event("download_transcript", %{"format" => format}, socket) do
    # Would trigger download in production based on format
    format_name =
      case format do
        "pdf" -> "PDF"
        "txt" -> "Text"
        "csv" -> "CSV"
        _ -> "File"
      end

    {:noreply, put_flash(socket, :info, "Downloading transcript as #{format_name}...")}
  end

  @impl true
  def handle_event("download_transcript", _params, socket) do
    # Default to text format
    {:noreply, put_flash(socket, :info, "Downloading transcript as Text...")}
  end

  @impl true
  def handle_info({:transcript_completed, %{transcript: updated_transcript}}, socket) do
    # Update transcript if it's the one being viewed
    socket =
      if socket.assigns[:transcript] && socket.assigns.transcript.id == updated_transcript.id do
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background">
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%= if @transcript do %>
          <!-- Single Transcript View -->
          <div class="space-y-6">
            <!-- Header -->
            <div class="bg-card text-card-foreground rounded-lg border p-6">
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div>
                  <h1 class="text-2xl font-bold text-foreground mb-2">Session Transcript</h1>
                  <p class="text-muted-foreground">
                    <%= Calendar.strftime(@transcript.inserted_at, "%B %d, %Y at %I:%M %p") %>
                  </p>
                </div>
                <div class="flex flex-wrap gap-2">
                  <button
                    phx-click="copy_transcript"
                    class="inline-flex items-center px-4 py-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 rounded-md text-sm font-medium transition-colors"
                    aria-label="Copy transcript to clipboard"
                  >
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                    </svg>
                    Copy
                  </button>
                  <button
                    phx-click="download_transcript"
                    class="inline-flex items-center px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md text-sm font-medium transition-colors"
                    aria-label="Download transcript"
                  >
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    Download
                  </button>
                </div>
              </div>
            </div>

            <!-- Transcript Content -->
            <div class="bg-card text-card-foreground rounded-lg border">
              <div class="p-6 border-b border-border">
                <div class="flex items-center justify-between">
                  <h2 class="text-xl font-semibold text-foreground">Conversation History</h2>
                  <button
                    phx-click="toggle_full_transcript"
                    class="text-sm text-primary hover:text-primary/80 font-medium transition-colors"
                    aria-label={if(@show_full_transcript, do: "Show summary", else: "Show full transcript")}
                  >
                    <%= if @show_full_transcript, do: "Show Summary", else: "Show Full" %>
                  </button>
                </div>
              </div>

              <div class="p-6">
                <%= if @transcript.segments && length(@transcript.segments) > 0 do %>
                  <div class="space-y-4 max-h-96 overflow-y-auto">
                    <%= for {segment, index} <- Enum.with_index(@transcript.segments) do %>
                      <div class={"flex gap-4 p-4 rounded-lg transition-colors #{if(@playing_segment == index, do: "bg-muted", else: "hover:bg-muted/50")}"}>
                        <div class="flex-shrink-0">
                          <div class="w-8 h-8 bg-primary rounded-full flex items-center justify-center">
                            <span class="text-xs font-medium text-primary-foreground">
                              <%= segment.speaker || "U" %>
                            </span>
                          </div>
                        </div>
                        <div class="flex-1 min-w-0">
                          <div class="flex items-center gap-3 mb-2">
                            <span class="text-sm font-medium text-foreground">
                              <%= segment.speaker || "Unknown" %>
                            </span>
                            <span class="text-xs text-muted-foreground">
                              <%= format_timestamp(segment.timestamp) %>
                            </span>
                            <%= if segment.confidence do %>
                              <span class="text-xs text-muted-foreground">
                                <%= confidence_percentage(segment.confidence) %>%
                              </span>
                            <% end %>
                          </div>
                          <p class="text-sm text-foreground leading-relaxed">
                            <%= segment.text %>
                          </p>
                          <%= if segment.sentiment do %>
                            <div class="mt-2 flex items-center gap-2">
                              <span class="text-xs text-muted-foreground">Sentiment:</span>
                              <span class={"text-xs font-medium #{sentiment_color(segment.sentiment)}"}>
                                <%= sentiment_indicator(segment.sentiment) %>
                              </span>
                            </div>
                          <% end %>
                        </div>
                        <div class="flex-shrink-0">
                          <button
                            phx-click="play_segment"
                            phx-value-index={index}
                            class="p-2 text-muted-foreground hover:text-foreground hover:bg-accent rounded-md transition-colors"
                            aria-label="Play this segment"
                          >
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1.586a1 1 0 01.707.293l.707.707A1 1 0 0012.414 11H13m-3 3h1.586a1 1 0 01.707.293l.707.707A1 1 0 0012.414 14H13m0-6a2 2 0 100 4 2 2 0 000-4z" />
                            </svg>
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <div class="text-center py-12">
                    <div class="mx-auto flex items-center justify-center h-24 w-24 rounded-full bg-muted mb-4">
                      <svg class="h-12 w-12 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                    </div>
                    <h3 class="text-lg font-medium text-foreground mb-2">No Transcript Available</h3>
                    <p class="text-muted-foreground">The transcript is being processed or no conversation data is available.</p>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Export Options -->
            <div class="bg-card text-card-foreground rounded-lg border p-6">
              <h2 class="text-xl font-semibold text-foreground mb-4">Export Options</h2>
              <div class="grid sm:grid-cols-3 gap-4">
                <button
                  phx-click="download_transcript"
                  phx-value-format="txt"
                  class="flex items-center justify-center p-4 border border-border rounded-lg hover:bg-accent hover:text-accent-foreground transition-colors"
                  aria-label="Download as text file"
                >
                  <div class="text-center">
                    <svg class="w-8 h-8 mx-auto mb-2 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <span class="text-sm font-medium">Text (.txt)</span>
                  </div>
                </button>

                <button
                  phx-click="download_transcript"
                  phx-value-format="pdf"
                  class="flex items-center justify-center p-4 border border-border rounded-lg hover:bg-accent hover:text-accent-foreground transition-colors"
                  aria-label="Download as PDF"
                >
                  <div class="text-center">
                    <svg class="w-8 h-8 mx-auto mb-2 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <span class="text-sm font-medium">PDF</span>
                  </div>
                </button>

                <button
                  phx-click="download_transcript"
                  phx-value-format="csv"
                  class="flex items-center justify-center p-4 border border-border rounded-lg hover:bg-accent hover:text-accent-foreground transition-colors"
                  aria-label="Download as CSV"
                >
                  <div class="text-center">
                    <svg class="w-8 h-8 mx-auto mb-2 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M3 14h18m-9-4v8m-7 0h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                    </svg>
                    <span class="text-sm font-medium">CSV</span>
                  </div>
                </button>
              </div>
            </div>
          </div>
        <% else %>
          <!-- Transcript List View -->
          <div class="space-y-6">
            <!-- Header -->
            <div class="text-center">
              <h1 class="text-3xl font-bold text-foreground mb-2">My Transcripts</h1>
              <p class="text-muted-foreground">Review and manage your conversation transcripts</p>
            </div>

            <!-- Transcripts List -->
            <%= if @transcripts && length(@transcripts) > 0 do %>
              <div class="grid gap-4">
                <%= for transcript <- @transcripts do %>
                  <div class="bg-card text-card-foreground rounded-lg border p-6 hover:shadow-md transition-shadow">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <div class="flex items-center gap-3 mb-2">
                          <h3 class="text-lg font-semibold text-foreground">
                            <%= Calendar.strftime(transcript.inserted_at, "%B %d, %Y") %>
                          </h3>
                          <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_badge_class(transcript.status)}"}>
                            <%= status_text(transcript.status) %>
                          </span>
                        </div>
                        <p class="text-muted-foreground text-sm mb-3">
                          <%= Calendar.strftime(transcript.inserted_at, "%I:%M %p") %> •
                          <%= format_duration(transcript.duration || 0) %>
                        </p>
                        <%= if transcript.summary do %>
                          <p class="text-foreground text-sm line-clamp-2">
                            <%= truncate_text(transcript.summary, 150) %>
                          </p>
                        <% end %>
                      </div>
                      <div class="ml-4">
                        <button
                          phx-click="select_transcript"
                          phx-value-transcript_id={transcript.id}
                          class="inline-flex items-center px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md text-sm font-medium transition-colors"
                          aria-label="View transcript details"
                        >
                          View Details
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="text-center py-12">
                <div class="mx-auto flex items-center justify-center h-24 w-24 rounded-full bg-muted mb-4">
                  <svg class="h-12 w-12 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <h3 class="text-lg font-medium text-foreground mb-2">No Transcripts Yet</h3>
                <p class="text-muted-foreground">Your conversation transcripts will appear here once sessions are completed.</p>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions
  defp status_badge_class(status) do
    case status do
      "completed" -> "bg-green-100 text-green-800"
      "processing" -> "bg-yellow-100 text-yellow-800"
      "failed" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp status_text(status) do
    case status do
      "completed" -> "Completed"
      "processing" -> "Processing"
      "failed" -> "Failed"
      _ -> "Unknown"
    end
  end

  defp sentiment_indicator(sentiment) do
    case sentiment do
      "positive" -> "😊 Positive"
      "negative" -> "😔 Negative"
      "neutral" -> "😐 Neutral"
      _ -> "🤔 Unknown"
    end
  end

  defp sentiment_color(sentiment) do
    case sentiment do
      "positive" -> "text-green-600"
      "negative" -> "text-red-600"
      "neutral" -> "text-gray-600"
      _ -> "text-gray-600"
    end
  end

  defp format_duration(seconds) when is_number(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading("#{remaining_seconds}", 2, "0")}"
  end

  defp format_duration(_), do: "0:00"

  defp format_timestamp(timestamp) do
    case timestamp do
      %DateTime{} = dt -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> "00:00:00"
    end
  end

  defp confidence_percentage(confidence) when is_number(confidence) do
    "#{round(confidence * 100)}%"
  end

  defp confidence_percentage(_), do: "N/A"

  defp truncate_text(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end
end
