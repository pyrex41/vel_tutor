defmodule ViralEngineWeb.RewardsLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.XPContext
  require Logger

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = ViralEngine.Accounts.get_user_by_session_token(user_token)

    if connected?(socket) do
      # Subscribe to XP and reward events
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:xp")
      Phoenix.PubSub.subscribe(ViralEngine.PubSub, "user:#{user.id}:rewards")
    end

    # Get user's XP
    {:ok, user_xp} = XPContext.get_user_xp(user.id)

    # Get available rewards
    rewards = XPContext.list_rewards()

    # Get user's claimed rewards
    user_rewards = XPContext.get_user_rewards(user.id)

    # Group rewards by type
    grouped_rewards = Enum.group_by(rewards, & &1.reward_type)

    # Get claimed reward IDs
    claimed_ids = MapSet.new(Enum.map(user_rewards, & &1.user_reward.reward_id))

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:user_xp, user_xp)
      |> assign(:rewards, rewards)
      |> assign(:filtered_rewards, rewards)
      |> assign(:user_rewards, user_rewards)
      |> assign(:grouped_rewards, grouped_rewards)
      |> assign(:claimed_ids, claimed_ids)
      |> assign(:filter, :all)
      |> assign(:show_claim_modal, false)
      |> assign(:selected_reward, nil)
      |> assign(:show_inventory, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"type" => filter_type}, socket) do
    new_filter = String.to_existing_atom(filter_type)

    filtered_rewards =
      case new_filter do
        :all ->
          socket.assigns.rewards

        :affordable ->
          Enum.filter(socket.assigns.rewards, fn r ->
            r.xp_cost <= socket.assigns.user_xp.total_xp &&
              r.level_required <= socket.assigns.user_xp.level
          end)

        :owned ->
          socket.assigns.rewards
          |> Enum.filter(fn r -> MapSet.member?(socket.assigns.claimed_ids, r.id) end)

        type when type in [:cosmetic, :powerup, :avatar, :theme, :special] ->
          Enum.filter(socket.assigns.rewards, &(&1.reward_type == Atom.to_string(type)))

        _ ->
          socket.assigns.rewards
      end

    {:noreply, assign(socket, filter: new_filter, filtered_rewards: filtered_rewards)}
  end

  @impl true
  def handle_event("open_claim_modal", %{"reward_id" => reward_id_str}, socket) do
    reward_id = String.to_integer(reward_id_str)
    reward = Enum.find(socket.assigns.rewards, &(&1.id == reward_id))

    # Check if user can afford this reward
    can_afford = reward.xp_cost <= socket.assigns.user_xp.total_xp
    level_met = reward.level_required <= socket.assigns.user_xp.level
    already_owned = MapSet.member?(socket.assigns.claimed_ids, reward_id)

    {:noreply,
     socket
     |> assign(:show_claim_modal, true)
     |> assign(:selected_reward, reward)
     |> assign(:can_afford, can_afford)
     |> assign(:level_met, level_met)
     |> assign(:already_owned, already_owned)}
  end

  @impl true
  def handle_event("close_claim_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_claim_modal, false)
     |> assign(:selected_reward, nil)}
  end

  @impl true
  def handle_event("claim_reward", %{"reward_id" => reward_id_str}, socket) do
    reward_id = String.to_integer(reward_id_str)

    case XPContext.claim_reward(socket.assigns.user_id, reward_id) do
      {:ok, _user_reward, updated_user_xp} ->
        # Refresh data
        user_rewards = XPContext.get_user_rewards(socket.assigns.user_id)
        claimed_ids = MapSet.new(Enum.map(user_rewards, & &1.user_reward.reward_id))

        {:noreply,
         socket
         |> assign(:user_xp, updated_user_xp)
         |> assign(:user_rewards, user_rewards)
         |> assign(:claimed_ids, claimed_ids)
         |> assign(:show_claim_modal, false)
         |> assign(:selected_reward, nil)
         |> put_flash(:success, "Reward claimed successfully! 🎉")}

      {:error, :insufficient_xp} ->
        {:noreply,
         socket
         |> put_flash(:error, "Not enough XP to claim this reward.")}

      {:error, :level_too_low} ->
        {:noreply,
         socket
         |> put_flash(:error, "Your level is too low to claim this reward.")}

      {:error, :out_of_stock} ->
        {:noreply,
         socket
         |> put_flash(:error, "This reward is out of stock.")}

      {:error, reason} ->
        Logger.error("Failed to claim reward: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to claim reward. Please try again.")}
    end
  end

  @impl true
  def handle_event("toggle_inventory", _params, socket) do
    {:noreply, assign(socket, :show_inventory, !socket.assigns.show_inventory)}
  end

  @impl true
  def handle_event("equip_reward", %{"reward_id" => reward_id_str}, socket) do
    reward_id = String.to_integer(reward_id_str)

    case XPContext.equip_reward(socket.assigns.user_id, reward_id) do
      {:ok, _user_reward} ->
        # Refresh user rewards
        user_rewards = XPContext.get_user_rewards(socket.assigns.user_id)

        {:noreply,
         socket
         |> assign(:user_rewards, user_rewards)
         |> put_flash(:success, "Reward equipped!")}

      {:error, reason} ->
        Logger.error("Failed to equip reward: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to equip reward.")}
    end
  end

  @impl true
  def handle_event("activate_powerup", %{"reward_id" => reward_id_str}, socket) do
    reward_id = String.to_integer(reward_id_str)

    case XPContext.activate_powerup(socket.assigns.user_id, reward_id) do
      {:ok, _user_reward} ->
        # Refresh user rewards
        user_rewards = XPContext.get_user_rewards(socket.assigns.user_id)

        {:noreply,
         socket
         |> assign(:user_rewards, user_rewards)
         |> put_flash(:success, "Powerup activated! ⚡")}

      {:error, reason} ->
        Logger.error("Failed to activate powerup: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(:error, "Failed to activate powerup.")}
    end
  end

  @impl true
  def handle_info({:xp_gained, %{amount: amount, source: source}}, socket) do
    # Refresh user XP
    {:ok, user_xp} = XPContext.get_user_xp(socket.assigns.user_id)

    {:noreply,
     socket
     |> assign(:user_xp, user_xp)
     |> put_flash(:info, "+#{amount} XP from #{source}!")}
  end

  @impl true
  def handle_info({:level_up, %{new_level: new_level}}, socket) do
    # Refresh user XP
    {:ok, user_xp} = XPContext.get_user_xp(socket.assigns.user_id)

    {:noreply,
     socket
     |> assign(:user_xp, user_xp)
     |> put_flash(:success, "🎉 Level Up! You're now level #{new_level}!")}
  end

  @impl true
  def handle_info({:reward_claimed, %{reward: _reward}}, socket) do
    # Already handled in claim_reward event
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background py-8 px-4" role="main">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-foreground mb-2">Rewards Store</h1>
          <p class="text-muted-foreground">Spend your XP on exclusive rewards and power-ups!</p>
        </div>

        <!-- XP Status -->
        <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6 mb-8">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-xl font-semibold text-foreground mb-1">Your XP Balance</h2>
              <p class="text-muted-foreground">Level <%= @user_xp.level %></p>
            </div>
            <div class="text-right">
              <div class="text-3xl font-bold text-foreground"><%= @user_xp.total_xp %></div>
              <div class="text-sm text-muted-foreground">Total XP</div>
            </div>
          </div>

          <!-- Level Progress -->
          <div class="space-y-2">
            <div class="flex justify-between text-sm">
              <span class="text-muted-foreground">Level Progress</span>
              <span class="text-foreground font-medium"><%= @user_xp.current_xp %> / <%= @user_xp.xp_to_next_level %> XP</span>
            </div>
            <div class="w-full bg-secondary rounded-full h-3">
              <div
                class="bg-primary h-3 rounded-full transition-all duration-300"
                style={"width: #{min(100, (@user_xp.current_xp / @user_xp.xp_to_next_level) * 100)}%"}
              ></div>
            </div>
          </div>
        </div>

        <!-- Filters -->
        <div class="flex flex-wrap gap-2 mb-6">
          <button
            phx-click="filter"
            phx-value-type="all"
            class={"px-4 py-2 rounded-md text-sm font-medium transition-colors #{if @filter == :all, do: "bg-primary text-primary-foreground", else: "bg-secondary text-secondary-foreground hover:bg-secondary/80"}"}
            aria-pressed={@filter == :all}
          >
            All Rewards
          </button>

          <button
            phx-click="filter"
            phx-value-type="affordable"
            class={"px-4 py-2 rounded-md text-sm font-medium transition-colors #{if @filter == :affordable, do: "bg-primary text-primary-foreground", else: "bg-secondary text-secondary-foreground hover:bg-secondary/80"}"}
            aria-pressed={@filter == :affordable}
          >
            Affordable
          </button>

          <button
            phx-click="filter"
            phx-value-type="owned"
            class={"px-4 py-2 rounded-md text-sm font-medium transition-colors #{if @filter == :owned, do: "bg-primary text-primary-foreground", else: "bg-secondary text-secondary-foreground hover:bg-secondary/80"}"}
            aria-pressed={@filter == :owned}
          >
            Owned
          </button>

          <%= for {type, rewards} <- @grouped_rewards do %>
            <button
              phx-click="filter"
              phx-value-type={type}
              class={"px-4 py-2 rounded-md text-sm font-medium transition-colors capitalize #{if @filter == String.to_atom(type), do: "bg-primary text-primary-foreground", else: "bg-secondary text-secondary-foreground hover:bg-secondary/80"}"}
              aria-pressed={@filter == String.to_atom(type)}
            >
              <%= type %> (<%= length(rewards) %>)
            </button>
          <% end %>
        </div>

        <!-- Inventory Toggle -->
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-xl font-semibold text-foreground">Available Rewards</h2>
          <button
            phx-click="toggle_inventory"
            class="flex items-center space-x-2 px-4 py-2 bg-secondary text-secondary-foreground hover:bg-secondary/80 rounded-md text-sm font-medium transition-colors"
            aria-expanded={@show_inventory}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
            <span><%= if @show_inventory, do: "Hide", else: "Show" %> Inventory</span>
          </button>
        </div>

        <!-- Rewards Grid -->
        <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
          <%= for reward <- (@filtered_rewards || @rewards) do %>
            <div class="bg-card text-card-foreground rounded-lg border shadow-sm p-6 hover:shadow-md transition-shadow">
              <div class="flex items-start justify-between mb-4">
                <div class="flex-1">
                  <h3 class="text-lg font-semibold text-foreground mb-1"><%= reward.name %></h3>
                  <p class="text-sm text-muted-foreground mb-2"><%= reward.description %></p>
                  <div class="flex items-center space-x-2">
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-secondary text-secondary-foreground capitalize">
                      <%= reward.reward_type %>
                    </span>
                    <%= if reward.level_required > 1 do %>
                      <span class="text-xs text-muted-foreground">Level <%= reward.level_required %></span>
                    <% end %>
                  </div>
                </div>
                <%= if MapSet.member?(@claimed_ids, reward.id) do %>
                  <div class="flex-shrink-0">
                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Owned
                    </span>
                  </div>
                <% end %>
              </div>

              <div class="flex items-center justify-between">
                <div class="text-lg font-bold text-foreground"><%= reward.xp_cost %> XP</div>
                <button
                  phx-click="open_claim_modal"
                  phx-value-reward_id={reward.id}
                  class={"px-4 py-2 rounded-md text-sm font-medium transition-colors #{if MapSet.member?(@claimed_ids, reward.id), do: "bg-green-100 text-green-800 hover:bg-green-200", else: if(reward.xp_cost <= @user_xp.total_xp && reward.level_required <= @user_xp.level, do: "bg-primary text-primary-foreground hover:bg-primary/90", else: "bg-muted text-muted-foreground cursor-not-allowed")}"}
                  disabled={MapSet.member?(@claimed_ids, reward.id) || reward.xp_cost > @user_xp.total_xp || reward.level_required > @user_xp.level}
                  aria-label={"Claim #{reward.name} for #{reward.xp_cost} XP"}
                >
                  <%= if MapSet.member?(@claimed_ids, reward.id), do: "Owned", else: "Claim" %>
                </button>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Inventory Section -->
        <%= if @show_inventory && length(@user_rewards) > 0 do %>
          <div class="bg-card text-card-foreground rounded-lg border p-6">
            <h2 class="text-xl font-semibold text-foreground mb-4">Your Inventory</h2>
            <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for user_reward <- @user_rewards do %>
                <div class="bg-muted rounded-lg p-4">
                  <div class="flex items-start justify-between mb-2">
                    <div>
                      <h4 class="font-medium text-foreground"><%= user_reward.reward.name %></h4>
                      <p class="text-sm text-muted-foreground"><%= user_reward.reward.description %></p>
                    </div>
                    <%= if user_reward.equipped do %>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-primary text-primary-foreground">
                        Equipped
                      </span>
                    <% end %>
                  </div>

                  <div class="flex space-x-2 mt-3">
                    <%= if user_reward.reward.reward_type in ["cosmetic", "avatar", "theme"] do %>
                      <button
                        phx-click="equip_reward"
                        phx-value-reward_id={user_reward.reward.id}
                        class="px-3 py-1 bg-primary text-primary-foreground hover:bg-primary/90 rounded text-xs font-medium transition-colors"
                        disabled={user_reward.equipped}
                      >
                        <%= if user_reward.equipped, do: "Equipped", else: "Equip" %>
                      </button>
                    <% end %>

                    <%= if user_reward.reward.reward_type == "powerup" do %>
                      <button
                        phx-click="activate_powerup"
                        phx-value-reward_id={user_reward.reward.id}
                        class="px-3 py-1 bg-primary text-primary-foreground hover:bg-primary/90 rounded text-xs font-medium transition-colors"
                      >
                        Activate
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Claim Modal -->
    <%= if @show_claim_modal && @selected_reward do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_claim_modal" role="dialog" aria-modal="true" aria-labelledby="claim-modal-title">
        <div class="bg-card text-card-foreground rounded-lg border shadow-lg max-w-md w-full p-6" phx-click="stop-propagation">
          <h3 id="claim-modal-title" class="text-xl font-bold text-foreground mb-4">Claim Reward</h3>

          <div class="mb-6">
            <div class="flex items-center space-x-4 mb-4">
              <div class="flex-1">
                <h4 class="font-semibold text-foreground"><%= @selected_reward.name %></h4>
                <p class="text-sm text-muted-foreground"><%= @selected_reward.description %></p>
              </div>
              <div class="text-right">
                <div class="text-2xl font-bold text-foreground"><%= @selected_reward.xp_cost %></div>
                <div class="text-sm text-muted-foreground">XP Cost</div>
              </div>
            </div>

            <div class="space-y-2 text-sm">
              <%= if @already_owned do %>
                <div class="flex items-center space-x-2 text-green-600">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                  <span>You already own this reward</span>
                </div>
              <% end %>

              <%= if not @can_afford do %>
                <div class="flex items-center space-x-2 text-red-600">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                  <span>Need <%= @selected_reward.xp_cost - @user_xp.total_xp %> more XP</span>
                </div>
              <% end %>

              <%= if not @level_met do %>
                <div class="flex items-center space-x-2 text-yellow-600">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                  </svg>
                  <span>Requires level <%= @selected_reward.level_required %></span>
                </div>
              <% end %>
            </div>
          </div>

          <div class="flex space-x-3">
            <%= if @can_afford && @level_met && not @already_owned do %>
              <button
                phx-click="claim_reward"
                phx-value-reward_id={@selected_reward.id}
                class="flex-1 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold px-4 py-2 rounded-md transition-colors"
              >
                Claim Reward
              </button>
            <% end %>

            <button
              phx-click="close_claim_modal"
              class="flex-1 text-muted-foreground hover:text-foreground font-medium py-2 transition-colors"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
