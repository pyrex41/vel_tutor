defmodule ViralEngineWeb.ProgressReelLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{Repo, ProgressReel}
  import Ecto.Query
  require Logger

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # Public reel view (no authentication required for parent sharing)
    reel =
      from(r in ProgressReel,
        where: r.reel_token == ^token and r.generation_status == "completed"
      )
      |> Repo.one()

    if reel do
      # Increment view count
      {:ok, updated_reel} = Repo.update(ProgressReel.increment_views(reel))

      socket =
        socket
        |> assign(:reel, updated_reel)
        |> assign(:public_view, true)
        |> assign(:show_share_modal, false)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Progress reel not found or expired")
       |> redirect(to: "/")}
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to new reel events
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:reels")
    end

    # Get user's reels
    reels =
      from(r in ProgressReel,
        where: r.student_id == ^user.id,
        where: r.generation_status == "completed",
        order_by: [desc: r.inserted_at],
        limit: 20
      )
      |> Repo.all()

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:reels, reels)
      |> assign(:selected_reel, nil)
      |> assign(:show_share_modal, false)
      |> assign(:public_view, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("view_reel", %{"reel_id" => reel_id_str}, socket) do
    reel_id = String.to_integer(reel_id_str)
    reel = Enum.find(socket.assigns.reels, &(&1.id == reel_id))

    {:noreply, assign(socket, :selected_reel, reel)}
  end

  @impl true
  def handle_event("open_share_modal", %{"reel_id" => reel_id_str}, socket) do
    reel_id = String.to_integer(reel_id_str)

    reel =
      if socket.assigns[:selected_reel] && socket.assigns.selected_reel.id == reel_id do
        socket.assigns.selected_reel
      else
        Enum.find(socket.assigns.reels, &(&1.id == reel_id))
      end

    {:noreply,
     socket
     |> assign(:selected_reel, reel)
     |> assign(:show_share_modal, true)}
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_event("copy_reel_link", _params, socket) do
    reel = socket.assigns.selected_reel
    reel_url = reel_url(reel)

    Logger.info("Progress reel link copied: #{reel_url}")

    {:noreply,
     socket
     |> put_flash(:success, "Reel link copied! Share with your parents 📱")}
  end

  @impl true
  def handle_event("share_reel", _params, socket) do
    reel = socket.assigns.selected_reel || socket.assigns.reel

    # Increment share count
    {:ok, updated_reel} = Repo.update(ProgressReel.increment_shares(reel))

    Logger.info("Progress reel #{reel.id} shared by student #{reel.student_id}")

    reels =
      if socket.assigns.public_view do
        nil
      else
        # Update reel in list
        Enum.map(socket.assigns.reels, fn r ->
          if r.id == updated_reel.id, do: updated_reel, else: r
        end)
      end

    socket =
      if reels do
        assign(socket, :reels, reels)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> put_flash(:success, "Reel shared! Your parents will love this! 🎉")}
  end

  @impl true
  def handle_event("download_reel", _params, socket) do
    # Would trigger download in production
    {:noreply,
     socket
     |> put_flash(:info, "Downloading reel...")}
  end

  @impl true
  def handle_info({:reel_ready, %{reel: reel}}, socket) do
    # New reel generated
    updated_reels = [reel | socket.assigns.reels]

    {:noreply,
     socket
     |> assign(:reels, updated_reels)
     |> put_flash(:success, "🎉 New progress reel ready! #{reel.title}")}
  end

  # Helper functions

  defp reel_url(reel) do
    "#{ViralEngineWeb.Endpoint.url()}/reel/#{reel.reel_token}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background">
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%= if @reel do %>
          <!-- Single Reel View (Public) -->
          <div class="space-y-6">
            <!-- Header -->
            <div class="text-center">
              <h1 class="text-3xl font-bold text-foreground mb-2"><%= @reel.title %></h1>
              <p class="text-muted-foreground">Celebrating your learning journey</p>
            </div>

            <!-- Story Cards Container -->
            <div class="relative">
              <div class="flex gap-4 overflow-x-auto snap-x snap-mandatory pb-4" id="reel-container">
                <%= for {story, index} <- Enum.with_index(@reel.stories || []) do %>
                  <div class="flex-shrink-0 w-80 snap-center">
                    <div class="bg-card text-card-foreground rounded-lg border shadow-lg overflow-hidden hover:shadow-xl transition-shadow">
                      <!-- Story Header -->
                      <div class="p-4 border-b border-border">
                        <div class="flex items-center gap-3">
                          <div class="w-10 h-10 bg-primary rounded-full flex items-center justify-center">
                            <span class="text-sm font-medium text-primary-foreground">
                              <%= String.first(story.title || "A") %>
                            </span>
                          </div>
                          <div>
                            <h3 class="font-semibold text-foreground"><%= story.title %></h3>
                            <p class="text-xs text-muted-foreground">
                              <%= time_ago(story.timestamp) %>
                            </p>
                          </div>
                        </div>
                      </div>

                      <!-- Story Content -->
                      <div class="p-4">
                        <%= if story.type == "achievement" do %>
                          <div class="text-center">
                            <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
                              <svg class="w-8 h-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
                              </svg>
                            </div>
                            <h4 class="font-semibold text-foreground mb-2">Achievement Unlocked!</h4>
                            <p class="text-sm text-muted-foreground mb-4"><%= story.description %></p>
                            <%= if story.badge do %>
                              <div class="inline-flex items-center px-3 py-1 bg-primary/10 text-primary rounded-full text-sm font-medium">
                                🏆 <%= story.badge %>
                              </div>
                            <% end %>
                          </div>
                        <% else %>
                          <div class="space-y-4">
                            <p class="text-sm text-foreground"><%= story.description %></p>

                            <%= if story.progress do %>
                              <div>
                                <div class="flex items-center justify-between mb-2">
                                  <span class="text-sm font-medium text-foreground">Progress</span>
                                  <span class="text-sm text-muted-foreground"><%= story.progress %>%</span>
                                </div>
                                <div class="w-full bg-secondary rounded-full h-2">
                                  <div
                                    class="bg-primary h-2 rounded-full transition-all duration-1000 ease-out"
                                    style={"width: #{story.progress}%"}
                                  ></div>
                                </div>
                              </div>
                            <% end %>

                            <%= if story.stats do %>
                              <div class="grid grid-cols-2 gap-4">
                                <%= for {key, value} <- story.stats do %>
                                  <div class="text-center">
                                    <div class="text-lg font-bold text-foreground"><%= format_stat_value(value) %></div>
                                    <div class="text-xs text-muted-foreground capitalize"><%= key %></div>
                                  </div>
                                <% end %>
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>

                      <!-- Story Footer -->
                      <div class="p-4 border-t border-border bg-muted/50">
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-2">
                            <%= if story.reactions do %>
                              <div class="flex -space-x-1">
                                <%= for reaction <- story.reactions |> Enum.take(3) do %>
                                  <div class="w-6 h-6 bg-accent rounded-full flex items-center justify-center text-xs">
                                    <%= reaction %>
                                  </div>
                                <% end %>
                              </div>
                              <%= if length(story.reactions) > 3 do %>
                                <span class="text-xs text-muted-foreground">+<%= length(story.reactions) - 3 %></span>
                              <% end %>
                            <% end %>
                          </div>
                          <span class="text-xs text-muted-foreground">
                            <%= engagement_stats(story) %>
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- Navigation Arrows -->
              <button
                class="absolute left-2 top-1/2 -translate-y-1/2 w-10 h-10 bg-card border rounded-full shadow-lg flex items-center justify-center hover:bg-accent transition-colors"
                onclick="scrollReel(-320)"
                aria-label="Previous story"
              >
                <svg class="w-5 h-5 text-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                </svg>
              </button>

              <button
                class="absolute right-2 top-1/2 -translate-y-1/2 w-10 h-10 bg-card border rounded-full shadow-lg flex items-center justify-center hover:bg-accent transition-colors"
                onclick="scrollReel(320)"
                aria-label="Next story"
              >
                <svg class="w-5 h-5 text-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                </svg>
              </button>
            </div>

            <!-- Share Section -->
            <div class="bg-card text-card-foreground rounded-lg border p-6">
              <h2 class="text-xl font-semibold text-foreground mb-4">Share Your Progress</h2>
              <p class="text-muted-foreground mb-4">Show your parents how far you've come!</p>

              <div class="flex flex-col sm:flex-row gap-3">
                <input
                  type="text"
                  value={reel_url(@reel)}
                  readonly
                  class="flex-1 px-3 py-2 bg-background border border-input rounded-md text-sm"
                  aria-label="Share link"
                />
                <button
                  phx-click="copy_reel_link"
                  class="px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md text-sm font-medium transition-colors"
                  aria-label="Copy share link"
                >
                  Copy Link
                </button>
              </div>
            </div>
          </div>
        <% else %>
          <!-- Reel List View (Private) -->
          <div class="space-y-6">
            <!-- Header -->
            <div class="text-center">
              <h1 class="text-3xl font-bold text-foreground mb-2">My Progress Reels</h1>
              <p class="text-muted-foreground">Celebrate your achievements and milestones</p>
            </div>

            <!-- Reels Grid -->
            <%= if @reels && length(@reels) > 0 do %>
              <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
                <%= for reel <- @reels do %>
                  <div class="bg-card text-card-foreground rounded-lg border overflow-hidden hover:shadow-lg transition-shadow">
                    <div class="p-6">
                      <div class="flex items-start justify-between mb-4">
                        <div>
                          <h3 class="text-lg font-semibold text-foreground mb-1"><%= reel.title %></h3>
                          <p class="text-sm text-muted-foreground">
                            <%= time_ago(reel.inserted_at) %>
                          </p>
                        </div>
                        <div class="flex items-center gap-2">
                          <span class="inline-flex items-center px-2 py-1 bg-primary/10 text-primary rounded-full text-xs font-medium">
                            <%= reel_type_icon(reel.reel_type) %> <%= reel_type_name(reel.reel_type) %>
                          </span>
                        </div>
                      </div>

                      <p class="text-sm text-muted-foreground mb-4 line-clamp-2">
                        <%= reel.description || "A collection of your recent achievements and progress milestones." %>
                      </p>

                      <div class="flex items-center justify-between mb-4">
                        <div class="text-sm text-muted-foreground">
                          <%= stats_display(reel) %>
                        </div>
                      </div>

                      <div class="flex gap-2">
                        <button
                          phx-click="view_reel"
                          phx-value-reel_id={reel.id}
                          class="flex-1 bg-primary text-primary-foreground hover:bg-primary/90 font-medium py-2 px-4 rounded-md text-sm transition-colors"
                          aria-label="View reel"
                        >
                          View Reel
                        </button>
                        <button
                          phx-click="open_share_modal"
                          phx-value-reel_id={reel.id}
                          class="p-2 text-muted-foreground hover:text-foreground hover:bg-accent rounded-md transition-colors"
                          aria-label="Share reel"
                        >
                          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z" />
                          </svg>
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
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                </div>
                <h3 class="text-lg font-medium text-foreground mb-2">No Progress Reels Yet</h3>
                <p class="text-muted-foreground">Your progress reels will appear here as you achieve milestones and complete challenges.</p>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Share Modal -->
      <%= if @show_share_modal do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_share_modal" role="dialog" aria-modal="true" aria-labelledby="share-modal-title">
          <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6" phx-click="stop-propagation">
            <h3 id="share-modal-title" class="text-xl font-bold text-foreground mb-4">Share Your Progress Reel</h3>
            <p class="text-muted-foreground mb-6"><%= share_message(@selected_reel) %></p>

            <div class="space-y-4">
              <button
                phx-click="share_reel"
                class="w-full bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
                aria-label="Share reel"
              >
                Share with Parents
              </button>

              <button
                phx-click="download_reel"
                class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
                aria-label="Download reel"
              >
                Download Reel
              </button>

              <button
                phx-click="close_share_modal"
                class="w-full text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
                aria-label="Close share modal"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <script>
        function scrollReel(offset) {
          const container = document.getElementById('reel-container');
          if (container) {
            container.scrollBy({ left: offset, behavior: 'smooth' });
          }
        }

        // Add touch/swipe support
        let startX = 0;
        let scrollLeft = 0;

        document.addEventListener('DOMContentLoaded', function() {
          const container = document.getElementById('reel-container');
          if (container) {
            container.addEventListener('touchstart', function(e) {
              startX = e.touches[0].pageX - container.offsetLeft;
              scrollLeft = container.scrollLeft;
            });

            container.addEventListener('touchmove', function(e) {
              if (!startX) return;
              const x = e.touches[0].pageX - container.offsetLeft;
              const walk = (startX - x) * 2;
              container.scrollLeft = scrollLeft + walk;
            });

            container.addEventListener('touchend', function() {
              startX = 0;
            });
          }
        });
      </script>
    </div>
    """
  end

  # Helper functions

  defp share_message(reel) do
    "Share '#{reel.title}' with your parents to show them your amazing progress! 🎉"
  end

  defp reel_type_icon(type) do
    case type do
      "weekly" -> "📅"
      "monthly" -> "📊"
      "achievement" -> "🏆"
      "milestone" -> "🎯"
      _ -> "📱"
    end
  end

  defp reel_type_name(type) do
    case type do
      "weekly" -> "Weekly"
      "monthly" -> "Monthly"
      "achievement" -> "Achievement"
      "milestone" -> "Milestone"
      _ -> "Progress"
    end
  end

  defp time_ago(timestamp) do
    case timestamp do
      %DateTime{} = dt ->
        now = DateTime.utc_now()
        diff = DateTime.diff(now, dt, :second)

        cond do
          diff < 60 -> "Just now"
          diff < 3600 -> "#{div(diff, 60)}m ago"
          diff < 86400 -> "#{div(diff, 3600)}h ago"
          diff < 604_800 -> "#{div(diff, 86400)}d ago"
          true -> Calendar.strftime(dt, "%b %d")
        end

      _ ->
        "Recently"
    end
  end

  defp engagement_stats(story) do
    views = story.views || 0
    reactions = length(story.reactions || [])
    "#{views} views • #{reactions} reactions"
  end

  defp stats_display(reel) do
    stories_count = length(reel.stories || [])
    "#{stories_count} stories • #{reel.views || 0} views"
  end

  defp format_stat_value(value) do
    case value do
      v when is_number(v) and v >= 1000 -> "#{Float.round(v / 1000, 1)}K"
      v when is_number(v) -> "#{v}"
      _ -> "0"
    end
  end
end
