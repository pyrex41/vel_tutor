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
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-8 px-4">
      <div class="max-w-7xl mx-auto">
        <!-- Header Section -->
        <div class="bg-white rounded-xl shadow-lg p-6 mb-6">
          <div class="flex items-center justify-between mb-6">
            <div>
              <h1 class="text-4xl font-bold text-gray-900 mb-2">🏅 Badges & Achievements</h1>
              <p class="text-gray-600">Unlock badges by completing challenges and reaching milestones</p>
            </div>
            <div class="text-right">
              <p class="text-sm font-medium text-gray-600">Completion Rate</p>
              <p class="text-4xl font-bold text-blue-600">
                <%= if @total_badges > 0, do: round((@unlocked_count / @total_badges) * 100), else: 0 %>%
              </p>
            </div>
          </div>

          <!-- Stats Cards -->
          <div class="grid md:grid-cols-4 gap-4 mb-6">
            <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-4 border-2 border-blue-200">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-gray-600">Total Badges</p>
                  <p class="text-3xl font-bold text-gray-900"><%= @total_badges %></p>
                </div>
                <div class="w-12 h-12 rounded-full bg-blue-600 flex items-center justify-center">
                  <svg class="w-7 h-7 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                </div>
              </div>
            </div>

            <div class="bg-gradient-to-r from-green-50 to-teal-50 rounded-lg p-4 border-2 border-green-200">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-gray-600">Unlocked</p>
                  <p class="text-3xl font-bold text-gray-900"><%= @unlocked_count %></p>
                </div>
                <div class="w-12 h-12 rounded-full bg-green-600 flex items-center justify-center">
                  <svg class="w-7 h-7 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M10 2a5 5 0 00-5 5v2a2 2 0 00-2 2v5a2 2 0 002 2h10a2 2 0 002-2v-5a2 2 0 00-2-2H7V7a3 3 0 015.905-.75 1 1 0 001.937-.5A5.002 5.002 0 0010 2z" />
                  </svg>
                </div>
              </div>
            </div>

            <div class="bg-gradient-to-r from-gray-50 to-gray-100 rounded-lg p-4 border-2 border-gray-300">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-gray-600">Locked</p>
                  <p class="text-3xl font-bold text-gray-900"><%= @total_badges - @unlocked_count %></p>
                </div>
                <div class="w-12 h-12 rounded-full bg-gray-600 flex items-center justify-center">
                  <svg class="w-7 h-7 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
                  </svg>
                </div>
              </div>
            </div>

            <%= if @new_count > 0 do %>
              <div class="bg-gradient-to-r from-yellow-50 to-orange-50 rounded-lg p-4 border-2 border-yellow-300 animate-pulse">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm font-medium text-gray-600">New!</p>
                    <p class="text-3xl font-bold text-gray-900"><%= @new_count %></p>
                  </div>
                  <div class="w-12 h-12 rounded-full bg-yellow-500 flex items-center justify-center">
                    <svg class="w-7 h-7 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Filter Buttons -->
          <div class="flex flex-wrap gap-2">
            <button
              phx-click="filter"
              phx-value-type="all"
              class={"px-4 py-2 rounded-lg font-medium transition-all duration-200 #{if @filter == :all, do: "bg-blue-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
            >
              All Badges
            </button>
            <button
              phx-click="filter"
              phx-value-type="unlocked"
              class={"px-4 py-2 rounded-lg font-medium transition-all duration-200 #{if @filter == :unlocked, do: "bg-green-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
            >
              ✓ Unlocked
            </button>
            <button
              phx-click="filter"
              phx-value-type="locked"
              class={"px-4 py-2 rounded-lg font-medium transition-all duration-200 #{if @filter == :locked, do: "bg-gray-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
            >
              🔒 Locked
            </button>
            <%= if @new_count > 0 do %>
              <button
                phx-click="filter"
                phx-value-type="new"
                class={"px-4 py-2 rounded-lg font-medium transition-all duration-200 #{if @filter == :new, do: "bg-yellow-500 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
              >
                ⭐ New
              </button>
            <% end %>
            <div class="border-l-2 border-gray-300 mx-2"></div>
            <button
              phx-click="filter"
              phx-value-type="practice"
              class={"px-4 py-2 rounded-lg font-medium transition-all duration-200 #{if @filter == :practice, do: "bg-purple-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
            >
              📚 Practice
            </button>
            <button
              phx-click="filter"
              phx-value-type="diagnostic"
              class={"px-4 py-2 rounded-lg font-medium transition-all duration-200 #{if @filter == :diagnostic, do: "bg-indigo-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
            >
              🎯 Diagnostic
            </button>
            <button
              phx-click="filter"
              phx-value-type="social"
              class={"px-4 py-2 rounded-lg font-medium transition-all duration-200 #{if @filter == :social, do: "bg-pink-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
            >
              👥 Social
            </button>
            <button
              phx-click="filter"
              phx-value-type="achievement"
              class={"px-4 py-2 rounded-lg font-medium transition-all duration-200 #{if @filter == :achievement, do: "bg-orange-600 text-white shadow-md", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
            >
              🏆 Achievement
            </button>
          </div>
        </div>

        <!-- Badge Gallery -->
        <div class="grid md:grid-cols-3 lg:grid-cols-4 gap-6">
          <%= for item <- (if assigns[:filtered_collection], do: @filtered_collection, else: @collection) do %>
            <div
              class={"relative bg-white rounded-xl shadow-lg overflow-hidden transform transition-all duration-300 hover:scale-105 hover:shadow-2xl cursor-pointer #{if !item.unlocked, do: "opacity-60"}"}
              phx-click="view_badge"
              phx-value-badge_id={item.badge.id}
            >
              <!-- New Badge Indicator -->
              <%= if item.is_new do %>
                <div class="absolute top-2 right-2 z-10">
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-bold bg-yellow-400 text-yellow-900 animate-pulse shadow-lg">
                    NEW!
                  </span>
                </div>
              <% end %>

              <!-- Badge Icon Section -->
              <div class={"p-8 flex items-center justify-center #{category_bg_color(item.badge.category)}"}>
                <%= if item.unlocked do %>
                  <div class="text-7xl">
                    <%= badge_icon(item.badge.category) %>
                  </div>
                <% else %>
                  <div class="text-7xl opacity-30 filter grayscale">
                    🔒
                  </div>
                <% end %>
              </div>

              <!-- Badge Details -->
              <div class="p-4">
                <div class="flex items-center justify-between mb-2">
                  <h3 class="text-lg font-bold text-gray-900"><%= item.badge.name %></h3>
                  <%= rarity_badge(item.badge.rarity) %>
                </div>

                <p class="text-sm text-gray-600 mb-3"><%= item.badge.description %></p>

                <!-- Badge Stats -->
                <div class="flex items-center justify-between text-xs text-gray-500 mb-3">
                  <span class="flex items-center">
                    <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z" clip-rule="evenodd" />
                    </svg>
                    <%= if item.unlocked_at, do: Calendar.strftime(item.unlocked_at, "%b %d, %Y"), else: "Locked" %>
                  </span>
                  <span class="capitalize px-2 py-0.5 rounded bg-gray-100 font-medium">
                    <%= item.badge.category %>
                  </span>
                </div>

                <!-- Action Buttons -->
                <%= if item.unlocked do %>
                  <button
                    phx-click="open_share_modal"
                    phx-value-badge_id={item.badge.id}
                    class="w-full bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-semibold py-2 rounded-lg transition-all duration-200 shadow-md hover:shadow-lg"
                  >
                    Share Badge
                  </button>
                <% else %>
                  <div class="w-full bg-gray-300 text-gray-600 font-semibold py-2 rounded-lg text-center">
                    Complete to Unlock
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Empty State -->
        <%= if Enum.empty?((if assigns[:filtered_collection], do: @filtered_collection, else: @collection)) do %>
          <div class="bg-white rounded-xl shadow-lg p-12 text-center">
            <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-gray-100 mb-4">
              <svg class="h-10 w-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No Badges Found</h3>
            <p class="text-gray-600">Try adjusting your filters or complete more activities to earn badges!</p>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Share Modal -->
    <%= if @show_share_modal && @selected_badge do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50" phx-click="close_share_modal">
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8 transform transition-all" phx-click={Phoenix.LiveView.JS.exec("phx-remove", to: ".share-modal")}>
          <div class="text-center">
            <div class="mx-auto flex items-center justify-center h-24 w-24 rounded-full bg-gradient-to-br from-blue-400 to-indigo-500 mb-4 text-6xl">
              <%= badge_icon(@selected_badge.badge.category) %>
            </div>
            <h3 class="text-2xl font-bold text-gray-900 mb-2"><%= @selected_badge.badge.name %></h3>
            <%= rarity_badge(@selected_badge.badge.rarity) %>
            <p class="text-gray-600 my-4"><%= @selected_badge.badge.description %></p>

            <div class="bg-blue-50 rounded-lg p-4 mb-6">
              <p class="text-sm text-gray-700 font-medium">
                🎉 Share this achievement with your friends and inspire them to learn!
              </p>
            </div>

            <button
              phx-click="share_badge"
              phx-value-badge_id={@selected_badge.badge.id}
              class="w-full bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-semibold px-6 py-3 rounded-lg shadow-md hover:shadow-lg transition-all duration-200 mb-3"
            >
              Share on Feed
            </button>
            <button phx-click="close_share_modal" class="text-gray-500 hover:text-gray-700 text-sm font-medium">
              Close
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Helper functions for template

  defp category_bg_color(category) do
    case category do
      "practice" -> "bg-gradient-to-br from-purple-100 to-purple-200"
      "diagnostic" -> "bg-gradient-to-br from-indigo-100 to-indigo-200"
      "social" -> "bg-gradient-to-br from-pink-100 to-pink-200"
      "achievement" -> "bg-gradient-to-br from-orange-100 to-orange-200"
      _ -> "bg-gradient-to-br from-gray-100 to-gray-200"
    end
  end

  defp badge_icon(category) do
    case category do
      "practice" -> "📚"
      "diagnostic" -> "🎯"
      "social" -> "👥"
      "achievement" -> "🏆"
      _ -> "🏅"
    end
  end

  defp rarity_badge(rarity) do
    case rarity do
      "common" ->
        assigns = %{}
        ~H"<span class='inline-flex items-center px-2 py-1 rounded-full text-xs font-bold bg-gray-200 text-gray-700'>Common</span>"

      "rare" ->
        assigns = %{}
        ~H"<span class='inline-flex items-center px-2 py-1 rounded-full text-xs font-bold bg-blue-200 text-blue-700'>Rare</span>"

      "epic" ->
        assigns = %{}
        ~H"<span class='inline-flex items-center px-2 py-1 rounded-full text-xs font-bold bg-purple-200 text-purple-700'>Epic</span>"

      "legendary" ->
        assigns = %{}
        ~H"<span class='inline-flex items-center px-2 py-1 rounded-full text-xs font-bold bg-gradient-to-r from-yellow-400 to-orange-400 text-white shadow-lg'>⭐ Legendary</span>"

      _ ->
        assigns = %{}
        ~H"<span class='inline-flex items-center px-2 py-1 rounded-full text-xs font-bold bg-gray-200 text-gray-700'>Badge</span>"
    end
  end
end
