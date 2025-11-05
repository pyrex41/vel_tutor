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

  @impl true
  def render(assigns) do
    # Ensure filtered_collection exists
    assigns = assign_new(assigns, :filtered_collection, fn -> assigns.collection end)

    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-6">Badge Collection</h1>

          <!-- Stats Cards -->
          <div class="grid sm:grid-cols-3 gap-6 mb-6">
            <div class="bg-white border border-gray-200 rounded-lg p-6">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm font-medium text-gray-600">Unlocked</span>
                <svg class="w-6 h-6 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M10 2a8 8 0 100 16 8 8 0 000-16zm0 14a6 6 0 110-12 6 6 0 010 12z"/>
                  <path d="M8 7l4 3-4 3V7z"/>
                </svg>
              </div>
              <div class="text-3xl font-bold text-gray-900"><%= @unlocked_count %></div>
              <div class="text-sm text-gray-500">of <%= @total_badges %> total</div>
            </div>

            <div class="bg-white border border-gray-200 rounded-lg p-6">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm font-medium text-gray-600">Completion</span>
                <svg class="w-6 h-6 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                </svg>
              </div>
              <div class="text-3xl font-bold text-gray-900">
                <%= if @total_badges > 0, do: round(@unlocked_count / @total_badges * 100), else: 0 %>%
              </div>
              <div class="text-sm text-gray-500">Achievement rate</div>
            </div>

            <div class="bg-white border border-gray-200 rounded-lg p-6">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm font-medium text-gray-600">New Badges</span>
                <svg class="w-6 h-6 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                </svg>
              </div>
              <div class="text-3xl font-bold text-gray-900"><%= @new_count %></div>
              <div class="text-sm text-gray-500">Recently unlocked</div>
            </div>
          </div>

          <!-- Filters -->
          <div class="flex flex-wrap gap-2">
            <button
              phx-click="filter"
              phx-value-type="all"
              class={[
                "px-4 py-2 rounded-lg font-medium transition-colors",
                @filter == :all && "bg-blue-600 text-white",
                @filter != :all && "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
              ]}
            >
              All Badges
            </button>

            <button
              phx-click="filter"
              phx-value-type="unlocked"
              class={[
                "px-4 py-2 rounded-lg font-medium transition-colors",
                @filter == :unlocked && "bg-blue-600 text-white",
                @filter != :unlocked && "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
              ]}
            >
              Unlocked
            </button>

            <button
              phx-click="filter"
              phx-value-type="locked"
              class={[
                "px-4 py-2 rounded-lg font-medium transition-colors",
                @filter == :locked && "bg-blue-600 text-white",
                @filter != :locked && "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
              ]}
            >
              Locked
            </button>

            <%= if @new_count > 0 do %>
              <button
                phx-click="filter"
                phx-value-type="new"
                class={[
                  "px-4 py-2 rounded-lg font-medium transition-colors relative",
                  @filter == :new && "bg-blue-600 text-white",
                  @filter != :new && "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
                ]}
              >
                New
                <span class="ml-1 px-1.5 py-0.5 text-xs bg-red-500 text-white rounded-full"><%= @new_count %></span>
              </button>
            <% end %>
          </div>
        </div>

        <!-- Badge Grid -->
        <div class="grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          <%= for item <- @filtered_collection do %>
            <div class={[
              "bg-white border rounded-lg p-6 transition-all hover:shadow-lg relative",
              item.unlocked && "border-gray-200",
              !item.unlocked && "border-gray-200 opacity-60"
            ]}>
              <!-- New Badge Indicator -->
              <%= if item.is_new do %>
                <div class="absolute top-2 right-2 px-2 py-1 bg-red-500 text-white text-xs font-semibold rounded-full">
                  NEW
                </div>
              <% end %>

              <!-- Rarity Badge -->
              <div class="mb-4">
                <span class={[
                  "inline-block px-2 py-1 text-xs font-semibold rounded-full",
                  rarity_color(item.badge.rarity)
                ]}>
                  <%= String.upcase(item.badge.rarity) %>
                </span>
              </div>

              <!-- Badge Icon/Image -->
              <div class="flex justify-center mb-4">
                <div class={[
                  "w-24 h-24 rounded-full flex items-center justify-center text-4xl",
                  item.unlocked && "bg-gradient-to-br from-blue-400 to-blue-600",
                  !item.unlocked && "bg-gray-300"
                ]}>
                  <%= item.badge.icon || "🏆" %>
                </div>
              </div>

              <!-- Badge Name -->
              <h3 class="text-lg font-bold text-gray-900 text-center mb-2">
                <%= item.badge.name %>
              </h3>

              <!-- Badge Description -->
              <p class="text-sm text-gray-600 text-center mb-4">
                <%= item.badge.description %>
              </p>

              <!-- Unlock Criteria -->
              <%= if !item.unlocked do %>
                <div class="border-t border-gray-200 pt-4">
                  <p class="text-xs text-gray-500 mb-2">How to unlock:</p>
                  <p class="text-sm text-gray-700"><%= item.badge.unlock_criteria %></p>
                </div>
              <% end %>

              <!-- Unlocked Actions -->
              <%= if item.unlocked do %>
                <div class="flex gap-2 mt-4">
                  <button
                    phx-click="view_badge"
                    phx-value-badge_id={item.badge.id}
                    class="flex-1 px-4 py-2 text-sm font-medium text-blue-600 hover:text-blue-700 hover:bg-blue-50 rounded-lg transition-colors"
                  >
                    View
                  </button>

                  <button
                    phx-click="open_share_modal"
                    phx-value-badge_id={item.badge.id}
                    class="flex-1 px-4 py-2 text-sm font-medium text-blue-600 hover:text-blue-700 hover:bg-blue-50 rounded-lg transition-colors"
                  >
                    Share
                  </button>
                </div>

                <!-- Unlocked Date -->
                <%= if item.unlocked_at do %>
                  <div class="mt-4 text-xs text-center text-gray-500">
                    Unlocked <%= Calendar.strftime(item.unlocked_at, "%b %d, %Y") %>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Empty State -->
        <%= if length(@filtered_collection) == 0 do %>
          <div class="text-center py-16">
            <div class="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gray-100 text-gray-400 mb-4">
              <svg class="w-10 h-10" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 2a8 8 0 100 16 8 8 0 000-16zm0 14a6 6 0 110-12 6 6 0 010 12z"/>
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-gray-900 mb-2">No badges found</h3>
            <p class="text-gray-600">Try changing your filter or unlock more badges!</p>
          </div>
        <% end %>
      </div>

      <!-- Share Modal -->
      <%= if @show_share_modal && @selected_badge do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h3 class="text-xl font-bold text-gray-900 mb-4">Share Your Achievement</h3>

            <div class="text-center mb-6">
              <div class="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gradient-to-br from-blue-400 to-blue-600 text-4xl mb-3">
                <%= @selected_badge.badge.icon || "🏆" %>
              </div>
              <h4 class="text-lg font-semibold text-gray-900"><%= @selected_badge.badge.name %></h4>
            </div>

            <p class="text-gray-600 mb-6 text-center">
              Share this badge on your social media to inspire your friends!
            </p>

            <div class="flex gap-3">
              <button
                phx-click="share_badge"
                phx-value-badge_id={@selected_badge.badge.id}
                class="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
              >
                Share Now
              </button>

              <button
                phx-click="close_share_modal"
                class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp rarity_color(rarity) do
    case rarity do
      "common" -> "bg-gray-100 text-gray-800"
      "uncommon" -> "bg-green-100 text-green-800"
      "rare" -> "bg-blue-100 text-blue-800"
      "epic" -> "bg-purple-100 text-purple-800"
      "legendary" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
