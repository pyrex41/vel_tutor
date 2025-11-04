defmodule ViralEngineWeb.PrepPackLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{Repo, PrepPack}
  import Ecto.Query
  require Logger

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # Public prep pack view (can be shared)
    prep_pack = from(p in PrepPack,
      where: p.pack_token == ^token
    )
    |> Repo.one()

    if prep_pack do
      # Increment view count
      {:ok, updated_pack} = Repo.update(PrepPack.increment_views(prep_pack))

      socket =
        socket
        |> assign(:prep_pack, updated_pack)
        |> assign(:public_view, true)
        |> assign(:show_share_modal, false)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Prep pack not found or expired")
       |> redirect(to: "/")}
    end
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to new prep pack events
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:prep_packs")
    end

    # Get user's prep packs
    prep_packs = from(p in PrepPack,
      where: p.student_id == ^user.id,
      order_by: [desc: p.inserted_at],
      limit: 10
    )
    |> Repo.all()

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:prep_packs, prep_packs)
      |> assign(:selected_pack, nil)
      |> assign(:show_share_modal, false)
      |> assign(:public_view, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("view_pack", %{"pack_id" => pack_id_str}, socket) do
    pack_id = String.to_integer(pack_id_str)
    pack = Enum.find(socket.assigns.prep_packs, & &1.id == pack_id)

    {:noreply, assign(socket, :selected_pack, pack)}
  end

  @impl true
  def handle_event("open_share_modal", %{"pack_id" => pack_id_str}, socket) do
    pack_id = String.to_integer(pack_id_str)
    pack = if socket.assigns[:selected_pack] && socket.assigns.selected_pack.id == pack_id do
      socket.assigns.selected_pack
    else
      Enum.find(socket.assigns.prep_packs, & &1.id == pack_id)
    end

    {:noreply,
     socket
     |> assign(:selected_pack, pack)
     |> assign(:show_share_modal, true)}
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_event("copy_pack_link", _params, socket) do
    pack = socket.assigns.selected_pack || socket.assigns.prep_pack
    pack_url = prep_pack_url(pack)

    Logger.info("Prep pack link copied: #{pack_url}")

    {:noreply,
     socket
     |> put_flash(:success, "Prep pack link copied! Share with study buddies 📚")}
  end

  @impl true
  def handle_event("share_pack", _params, socket) do
    pack = socket.assigns.selected_pack || socket.assigns.prep_pack

    # Increment share count
    {:ok, updated_pack} = Repo.update(PrepPack.increment_shares(pack))

    Logger.info("Prep pack #{pack.id} shared by student #{pack.student_id}")

    packs = if socket.assigns.public_view do
      nil
    else
      # Update pack in list
      Enum.map(socket.assigns.prep_packs, fn p ->
        if p.id == updated_pack.id, do: updated_pack, else: p
      end)
    end

    socket = if packs do
      assign(socket, :prep_packs, packs)
    else
      socket
    end

    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> put_flash(:success, "Prep pack shared! 🎉")}
  end

  @impl true
  def handle_event("mark_completed", %{"pack_id" => pack_id_str}, socket) do
    pack_id = String.to_integer(pack_id_str)
    pack = Enum.find(socket.assigns.prep_packs, & &1.id == pack_id)

    if pack do
      {:ok, updated_pack} = Repo.update(PrepPack.mark_completed(pack))

      # Update list
      updated_packs = Enum.map(socket.assigns.prep_packs, fn p ->
        if p.id == updated_pack.id, do: updated_pack, else: p
      end)

      {:noreply,
       socket
       |> assign(:prep_packs, updated_packs)
       |> put_flash(:success, "Great job! Prep pack completed! ✅")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:prep_pack_ready, %{prep_pack: prep_pack}}, socket) do
    # New prep pack generated
    updated_packs = [prep_pack | socket.assigns.prep_packs]

    {:noreply,
     socket
     |> assign(:prep_packs, updated_packs)
     |> put_flash(:success, "📚 New prep pack ready! #{prep_pack.pack_name}")}
  end

  # Helper functions

  defp prep_pack_url(pack) do
    "#{ViralEngineWeb.Endpoint.url()}/prep/#{pack.pack_token}"
  end

  defp share_message(pack) do
    """
    Check out this study prep pack for #{pack.subject}!
    Topics: #{Enum.join(pack.target_topics, ", ")}
    Estimated time: #{pack.estimated_time_minutes} minutes
    #{prep_pack_url(pack)}
    """
  end

  defp status_badge_class(status) do
    case status do
      "generated" -> "bg-blue-100 text-blue-800"
      "shared" -> "bg-purple-100 text-purple-800"
      "viewed" -> "bg-yellow-100 text-yellow-800"
      "completed" -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp status_text(status) do
    case status do
      "generated" -> "Ready"
      "shared" -> "Shared"
      "viewed" -> "In Progress"
      "completed" -> "Completed"
      _ -> "Unknown"
    end
  end

  defp pack_type_icon(pack_type) do
    case pack_type do
      "practice_prep" -> "📝"
      "exam_prep" -> "📚"
      "review_pack" -> "🔄"
      "challenge_prep" -> "🎯"
      _ -> "📦"
    end
  end

  defp resource_count(resources) when is_map(resources) do
    Enum.reduce(resources, 0, fn {_key, items}, acc ->
      if is_list(items), do: acc + length(items), else: acc
    end)
  end
  defp resource_count(_), do: 0

  defp time_ago(datetime) when not is_nil(datetime) do
    seconds = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      seconds < 60 -> "Just now"
      seconds < 3600 -> "#{div(seconds, 60)} minutes ago"
      seconds < 86400 -> "#{div(seconds, 3600)} hours ago"
      true -> "#{div(seconds, 86400)} days ago"
    end
  end
  defp time_ago(_), do: "Unknown"
end
