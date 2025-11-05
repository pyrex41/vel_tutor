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
end
