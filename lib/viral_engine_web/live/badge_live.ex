defmodule ViralEngineWeb.BadgeLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.BadgeContext
  require Logger

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to badge unlock events
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:badges")
    end

    # Get user's badge collection
    collection = BadgeContext.get_user_badge_collection(user.id)

    # Calculate stats
    total_badges = length(collection)
    unlocked_count = Enum.count(collection, & &1.unlocked)
    new_count = Enum.count(collection, & &1.is_new)

    # Group by category
    grouped = Enum.group_by(collection, fn item -> item.badge.category end)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:collection, collection)
      |> assign(:total_badges, total_badges)
      |> assign(:unlocked_count, unlocked_count)
      |> assign(:new_count, new_count)
      |> assign(:grouped_badges, grouped)
      |> assign(:filter, :all)
      |> assign(:show_share_modal, false)
      |> assign(:selected_badge, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"type" => filter_type}, socket) do
    new_filter = String.to_existing_atom(filter_type)

    filtered_collection = case new_filter do
      :all ->
        socket.assigns.collection

      :unlocked ->
        Enum.filter(socket.assigns.collection, & &1.unlocked)

      :locked ->
        Enum.filter(socket.assigns.collection, &(!&1.unlocked))

      :new ->
        Enum.filter(socket.assigns.collection, & &1.is_new)

      category when category in [:practice, :diagnostic, :social, :achievement] ->
        Enum.filter(socket.assigns.collection, fn item ->
          item.badge.category == Atom.to_string(category)
        end)

      _ ->
        socket.assigns.collection
    end

    {:noreply, assign(socket, filter: new_filter, filtered_collection: filtered_collection)}
  end

  @impl true
  def handle_event("view_badge", %{"badge_id" => badge_id_str}, socket) do
    badge_id = String.to_integer(badge_id_str)

    # Mark badge as viewed (no longer new)
    BadgeContext.mark_badge_viewed(socket.assigns.user_id, badge_id)

    # Find the badge in collection
    badge_item = Enum.find(socket.assigns.collection, fn item ->
      item.badge.id == badge_id
    end)

    # Update collection to reflect viewed status
    updated_collection = Enum.map(socket.assigns.collection, fn item ->
      if item.badge.id == badge_id do
        %{item | is_new: false}
      else
        item
      end
    end)

    new_count = Enum.count(updated_collection, & &1.is_new)

    {:noreply,
     socket
     |> assign(:collection, updated_collection)
     |> assign(:new_count, new_count)
     |> assign(:selected_badge, badge_item)}
  end

  @impl true
  def handle_event("open_share_modal", %{"badge_id" => badge_id_str}, socket) do
    badge_id = String.to_integer(badge_id_str)

    badge_item = Enum.find(socket.assigns.collection, fn item ->
      item.badge.id == badge_id
    end)

    {:noreply,
     socket
     |> assign(:show_share_modal, true)
     |> assign(:selected_badge, badge_item)}
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> assign(:selected_badge, nil)}
  end

  @impl true
  def handle_event("share_badge", %{"badge_id" => badge_id_str}, socket) do
    badge_id = String.to_integer(badge_id_str)

    # Mark badge as shared
    BadgeContext.mark_badge_shared(socket.assigns.user_id, badge_id)

    Logger.info("User #{socket.assigns.user_id} shared badge #{badge_id}")

    {:noreply,
     socket
     |> put_flash(:success, "Badge shared! Your friends will see your achievement.")
     |> assign(:show_share_modal, false)
     |> assign(:selected_badge, nil)}
  end

  @impl true
  def handle_info({:badge_unlocked, %{badge: badge, user_badge: _user_badge}}, socket) do
    # Refresh collection when new badge is unlocked
    collection = BadgeContext.get_user_badge_collection(socket.assigns.user_id)
    unlocked_count = Enum.count(collection, & &1.unlocked)
    new_count = Enum.count(collection, & &1.is_new)

    {:noreply,
     socket
     |> assign(:collection, collection)
     |> assign(:unlocked_count, unlocked_count)
     |> assign(:new_count, new_count)
     |> put_flash(:info, "🎉 New badge unlocked: #{badge.name}!")}
  end

  # Helper functions

  defp badge_card_class(unlocked, is_new) do
    base = "rounded-lg p-6 border-2 transition-all hover:scale-105"

    cond do
      is_new and unlocked ->
        "#{base} border-yellow-400 bg-yellow-50 shadow-lg animate-pulse"

      unlocked ->
        "#{base} border-green-400 bg-white shadow-md"

      true ->
        "#{base} border-gray-300 bg-gray-50 opacity-60"
    end
  end

  defp rarity_color(rarity) do
    case rarity do
      "common" -> "text-gray-600"
      "rare" -> "text-blue-600"
      "epic" -> "text-purple-600"
      "legendary" -> "text-yellow-600"
      _ -> "text-gray-600"
    end
  end

  defp rarity_badge(rarity) do
    case rarity do
      "common" -> "Common"
      "rare" -> "Rare ⭐"
      "epic" -> "Epic ⭐⭐"
      "legendary" -> "Legendary ⭐⭐⭐"
      _ -> ""
    end
  end

  defp category_name(category) do
    case category do
      "practice" -> "Practice"
      "diagnostic" -> "Diagnostic"
      "social" -> "Social"
      "achievement" -> "Achievement"
      _ -> "Other"
    end
  end

  defp progress_bar_color(progress) do
    cond do
      progress >= 100 -> "bg-green-500"
      progress >= 75 -> "bg-blue-500"
      progress >= 50 -> "bg-yellow-500"
      progress >= 25 -> "bg-orange-500"
      true -> "bg-red-500"
    end
  end

  defp completion_percentage(unlocked_count, total_badges) do
    if total_badges > 0 do
      Float.round(unlocked_count / total_badges * 100, 1)
    else
      0.0
    end
  end
end
