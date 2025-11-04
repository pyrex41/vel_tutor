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

  # Note: UI helper functions have been removed until a render/1 function or .heex template is implemented.
  # Functions included: badge_card_class/2, rarity_color/1, rarity_badge/1,
  # category_name/1, progress_bar_color/1, completion_percentage/2
end
