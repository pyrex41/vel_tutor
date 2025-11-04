defmodule ViralEngineWeb.RewardsLive do
  use ViralEngineWeb, :live_view
  alias ViralEngine.{XPContext, UserXP}
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

    filtered_rewards = case new_filter do
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
        Enum.filter(socket.assigns.rewards, & &1.reward_type == Atom.to_string(type))

      _ ->
        socket.assigns.rewards
    end

    {:noreply, assign(socket, filter: new_filter, filtered_rewards: filtered_rewards)}
  end

  @impl true
  def handle_event("open_claim_modal", %{"reward_id" => reward_id_str}, socket) do
    reward_id = String.to_integer(reward_id_str)
    reward = Enum.find(socket.assigns.rewards, & &1.id == reward_id)

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
      {:ok, user_reward, updated_user_xp} ->
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
  def handle_info({:reward_claimed, %{reward: reward}}, socket) do
    # Already handled in claim_reward event
    {:noreply, socket}
  end

  # Note: UI helper functions have been removed until a render/1 function or .heex template is implemented.
  # Functions included: xp_progress_bar_width/1, rarity_color/1, rarity_text_color/1,
  # reward_type_name/1, can_claim_reward?/3, level_progress_class/1
end
