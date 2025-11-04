defmodule ViralEngineWeb.ProgressReelLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{Repo, ProgressReel}
  import Ecto.Query
  require Logger

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # Public reel view (no authentication required for parent sharing)
    reel = from(r in ProgressReel,
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
    reels = from(r in ProgressReel,
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
    reel = Enum.find(socket.assigns.reels, & &1.id == reel_id)

    {:noreply, assign(socket, :selected_reel, reel)}
  end

  @impl true
  def handle_event("open_share_modal", %{"reel_id" => reel_id_str}, socket) do
    reel_id = String.to_integer(reel_id_str)
    reel = if socket.assigns[:selected_reel] && socket.assigns.selected_reel.id == reel_id do
      socket.assigns.selected_reel
    else
      Enum.find(socket.assigns.reels, & &1.id == reel_id)
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

    reels = if socket.assigns.public_view do
      nil
    else
      # Update reel in list
      Enum.map(socket.assigns.reels, fn r ->
        if r.id == updated_reel.id, do: updated_reel, else: r
      end)
    end

    socket = if reels do
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

  # Note: Additional UI helper functions have been removed until
  # a render/1 function or .heex template is implemented.
  # Functions included: share_message/1, reel_type_icon/1, reel_type_name/1,
  # reel_type_color/1, format_timestamp/1, time_ago/1, engagement_stats/1,
  # is_expired?/1, stats_display/1, format_stat_value/1
end
