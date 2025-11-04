defmodule ViralEngineWeb.ParentProgressLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.ParentShareContext
  require Logger

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case ParentShareContext.get_share_by_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(:stage, :error)
         |> assign(:error_message, "Progress card not found")
         |> assign(:share, nil)}

      share ->
        # Mark as viewed
        ParentShareContext.mark_viewed(token)

        socket =
          socket
          |> assign(:stage, :view)
          |> assign(:share, share)
          |> assign(:progress_data, share.progress_data)
          |> assign(:share_link, ParentShareContext.generate_share_link(share))
          |> assign(:show_signup_modal, false)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("show_signup", _params, socket) do
    {:noreply, assign(socket, :show_signup_modal, true)}
  end

  @impl true
  def handle_event("close_signup", _params, socket) do
    {:noreply, assign(socket, :show_signup_modal, false)}
  end

  @impl true
  def handle_event("copy_link", _params, socket) do
    {:noreply, put_flash(socket, :success, "Link copied to clipboard!")}
  end

  # Helper functions

  defp format_share_type(type) do
    case type do
      "achievement" -> "Achievement"
      "milestone" -> "Milestone Reached"
      "weekly_progress" -> "Weekly Progress"
      "report_card" -> "Report Card"
      _ -> "Progress Update"
    end
  end

  defp get_card_icon(type) do
    case type do
      "achievement" -> "🏆"
      "milestone" -> "🎯"
      "weekly_progress" -> "📊"
      "report_card" -> "📝"
      _ -> "✨"
    end
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end
end
