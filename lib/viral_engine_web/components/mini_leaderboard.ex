defmodule ViralEngineWeb.Components.MiniLeaderboard do
  @moduledoc """
  Reusable mini-leaderboard component for subject pages.

  Displays top 10 performers with real-time updates via Phoenix Channels.
  Supports daily and weekly views with smooth transitions.
  """

  use Phoenix.Component
  import ViralEngineWeb.CoreComponents

  @doc """
  Renders a mini-leaderboard component.

  ## Attributes
  - `subject` - Subject name (required)
  - `period` - :daily or :weekly (default: :daily)
  - `entries` - Leaderboard entries (required)
  - `current_user_id` - Current user ID for highlighting
  - `title` - Custom title (optional)
  - `show_period_toggle` - Show daily/weekly toggle (default: true)
  """
  attr :subject, :string, required: true
  attr :period, :atom, default: :daily
  attr :entries, :list, required: true
  attr :current_user_id, :integer, default: nil
  attr :title, :string, default: nil
  attr :show_period_toggle, :boolean, default: true
  attr :class, :string, default: ""

  def mini_leaderboard(assigns) do
    ~H"""
    <div class={"bg-card text-card-foreground rounded-lg border shadow-sm p-6 #{@class}"}>
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center space-x-2">
          <svg class="w-6 h-6 text-amber-500" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
          </svg>
          <h3 class="text-lg font-semibold text-foreground">
            <%= @title || "#{String.capitalize(@subject)} Leaderboard" %>
          </h3>
        </div>

        <!-- Period Toggle -->
        <%= if @show_period_toggle do %>
          <div class="flex bg-muted rounded-lg p-1">
            <button
              phx-click="toggle_period"
              phx-value-period="daily"
              class={"px-3 py-1 text-sm font-medium rounded-md transition-colors #{if @period == :daily, do: "bg-primary text-primary-foreground", else: "text-muted-foreground hover:text-foreground"}"}
              aria-label="Show daily leaderboard"
            >
              Daily
            </button>
            <button
              phx-click="toggle_period"
              phx-value-period="weekly"
              class={"px-3 py-1 text-sm font-medium rounded-md transition-colors #{if @period == :weekly, do: "bg-primary text-primary-foreground", else: "text-muted-foreground hover:text-foreground"}"}
              aria-label="Show weekly leaderboard"
            >
              Weekly
            </button>
          </div>
        <% end %>
      </div>

      <!-- Leaderboard Entries -->
      <%= if length(@entries) > 0 do %>
        <div class="space-y-2" phx-update="stream" id="leaderboard-entries">
          <%= for entry <- @entries do %>
            <div
              id={"leaderboard-entry-#{entry.user_id}"}
              class={"flex items-center justify-between p-3 rounded-lg transition-all duration-300 #{if entry.user_id == @current_user_id, do: "bg-primary/10 border border-primary/30 ring-2 ring-primary/20", else: "bg-muted/50 hover:bg-muted"}"}
            >
              <!-- Rank & User -->
              <div class="flex items-center space-x-3 flex-1 min-w-0">
                <!-- Rank Badge -->
                <div class={"flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold #{rank_badge_color(entry.rank)}"}>
                  <%= if entry.rank <= 3 do %>
                    <%= rank_icon(entry.rank) %>
                  <% else %>
                    <span><%= entry.rank %></span>
                  <% end %>
                </div>

                <!-- User Info -->
                <div class="flex-1 min-w-0">
                  <p class={"font-medium truncate #{if entry.user_id == @current_user_id, do: "text-primary font-semibold", else: "text-foreground"}"}>
                    <%= if entry.user_id == @current_user_id do %>
                      You
                    <% else %>
                      Player #<%= String.slice(Integer.to_string(entry.user_id), -4..-1) %>
                    <% end %>
                  </p>
                  <p class="text-xs text-muted-foreground">
                    <%= entry.sessions %> <%= if entry.sessions == 1, do: "session", else: "sessions" %>
                  </p>
                </div>
              </div>

              <!-- Score -->
              <div class="flex-shrink-0 text-right">
                <div class="text-lg font-bold text-foreground"><%= round(entry.total_score || entry.avg_score || 0) %></div>
                <div class="text-xs text-muted-foreground">points</div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <!-- Empty State -->
        <div class="text-center py-8">
          <svg class="w-12 h-12 mx-auto text-muted-foreground/50 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
          </svg>
          <p class="text-sm text-muted-foreground">No rankings yet</p>
          <p class="text-xs text-muted-foreground mt-1">Be the first to practice <%= @subject %>!</p>
        </div>
      <% end %>

      <!-- Footer -->
      <div class="mt-4 pt-4 border-t border-border">
        <button
          phx-click="view_full_leaderboard"
          phx-value-subject={@subject}
          class="w-full text-sm font-medium text-primary hover:text-primary/80 transition-colors flex items-center justify-center space-x-1"
          aria-label="View full leaderboard"
        >
          <span>View Full Leaderboard</span>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp rank_badge_color(rank) do
    case rank do
      1 -> "bg-gradient-to-br from-yellow-400 to-amber-500 text-white"
      2 -> "bg-gradient-to-br from-gray-300 to-gray-400 text-gray-900"
      3 -> "bg-gradient-to-br from-orange-400 to-amber-600 text-white"
      _ -> "bg-secondary text-secondary-foreground"
    end
  end

  defp rank_icon(rank) do
    case rank do
      1 ->
        assigns = %{}

        ~H"""
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
        </svg>
        """

      2 ->
        assigns = %{}

        ~H"""
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
        </svg>
        """

      3 ->
        assigns = %{}

        ~H"""
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
        </svg>
        """

      _ ->
        ""
    end
  end
end
