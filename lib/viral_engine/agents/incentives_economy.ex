defmodule ViralEngine.Agents.IncentivesEconomy do
  @moduledoc """
  Incentives & Economy Agent - Manages reward distribution and redemption.

  This GenServer handles the complete reward lifecycle: granting rewards based on
  viral loop participation, tracking balances, enforcing caps, and processing redemptions.
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias ViralEngine.Support.DateTimeHelpers

  # Client API

  @doc """
  Starts the Incentives & Economy Agent GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Grants a reward to a user.

  ## Parameters
  - user_id: User to grant reward to
  - reward_type: Type of reward (:streak_shield, :ai_tutor_minutes, etc.)
  - amount: Amount to grant
  - context: Map with loop_id, event_id, etc.

  ## Returns
  - {:ok, reward} - Successfully granted
  - {:error, reason} - Grant failed
  """
  def grant_reward(user_id, reward_type, amount, context \\ %{}) do
    GenServer.call(__MODULE__, {:grant_reward, user_id, reward_type, amount, context})
  end

  @doc """
  Checks a user's balance for a reward type.

  ## Returns
  - {:ok, balance} - Current balance
  """
  def check_balance(user_id, reward_type) do
    GenServer.call(__MODULE__, {:check_balance, user_id, reward_type})
  end

  @doc """
  Redeems a reward from user's balance.

  ## Returns
  - {:ok, redemption} - Successfully redeemed
  - {:error, reason} - Redemption failed
  """
  def redeem_reward(user_id, reward_type, amount) do
    GenServer.call(__MODULE__, {:redeem_reward, user_id, reward_type, amount})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Preload user balances from database for faster access
    balances = preload_user_balances()

    state = %{
      daily_caps: load_daily_caps(),
      user_balances: balances,
      cost_tracking: %{},
      last_balance_sync: DateTimeHelpers.now_for_ecto()
    }

    Logger.info("Incentives & Economy Agent started with #{map_size(balances)} user balances")
    {:ok, state}
  end

  defp preload_user_balances do
    ViralEngine.ViralReward
    |> where([vr], is_nil(vr.redeemed_at))
    |> select([vr], %{
      user_id: vr.user_id,
      reward_type: vr.reward_type,
      balance: sum(vr.amount)
    })
    |> group_by([vr], [vr.user_id, vr.reward_type])
    |> Repo.all()
    |> Enum.reduce(%{}, fn %{user_id: user_id, reward_type: type, balance: bal}, acc ->
      key = {user_id, String.to_atom(type)}
      Map.put(acc, key, bal)
    end)
  end

  # Core Logic

  defp check_daily_cap(user_id, reward_type, amount, state) do
    cap = get_in(state.daily_caps, [reward_type]) || 1000
    granted_today = count_granted_today(user_id, reward_type)

    if granted_today + amount <= cap do
      {:ok, :within_cap}
    else
      {:error, :daily_cap_exceeded}
    end
  end

  defp create_reward(user_id, reward_type, amount, context) do
    reward = %ViralEngine.ViralReward{
      user_id: user_id,
      reward_type: to_string(reward_type),
      amount: amount,
      source_loop_id: to_string(context[:loop_id] || ""),
      source_event_id: to_string(context[:event_id] || ""),
      redeemed: false,
      expires_at: calculate_expiry(reward_type)
    }

    case ViralEngine.Repo.insert(reward) do
      {:ok, reward} -> {:ok, reward}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_balance(user_id, reward_type) do
    ViralEngine.ViralReward
    |> where([vr], vr.user_id == ^user_id and
                   vr.reward_type == ^to_string(reward_type) and
                   is_nil(vr.redeemed_at) and
                   (is_nil(vr.expires_at) or vr.expires_at > ^DateTimeHelpers.now_for_ecto()))
    |> select([vr], sum(vr.amount))
    |> Repo.one()
    |> case do
      nil -> {:ok, 0}
      total -> {:ok, total || 0}
    end
  end

  defp process_redemption(user_id, reward_type, amount) do
    with {:ok, balance} <- get_balance(user_id, reward_type),
         true <- balance >= amount do
      # Find unredeemed rewards to redeem
      rewards = ViralEngine.ViralReward
        |> where([vr], vr.user_id == ^user_id and
                       vr.reward_type == ^to_string(reward_type) and
                       is_nil(vr.redeemed_at) and
                       (is_nil(vr.expires_at) or vr.expires_at > ^DateTimeHelpers.now_for_ecto()))
        |> order_by([vr], asc: vr.inserted_at)
        |> limit(^amount)
        |> Repo.all()

      # Mark rewards as redeemed
      redeemed =
        rewards
        |> Enum.map(fn reward ->
          reward
          |> Ecto.Changeset.change(redeemed_at: DateTimeHelpers.now_for_ecto())
          |> Repo.update!()
        end)

      total_redeemed = length(redeemed)
      {:ok, %{redeemed_amount: total_redeemed, reward_ids: Enum.map(redeemed, & &1.id)}}
    else
      false -> {:error, :insufficient_balance}
      {:error, reason} -> {:error, reason}
    end
  end

  defp redeem_up_to_amount(rewards, amount, acc \\ [])
  defp redeem_up_to_amount([], remaining, acc), do: {Enum.reverse(acc), remaining}

  defp redeem_up_to_amount([reward | rest], remaining, acc) do
    if reward.amount <= remaining do
      redeem_up_to_amount(rest, remaining - reward.amount, [reward | acc])
    else
      # Partial redemption not supported; skip this reward
      redeem_up_to_amount(rest, remaining, acc)
    end
  end

  # Helpers

  defp load_daily_caps do
    %{
      # Max 60 min/day from viral
      ai_tutor_minutes: 60,
      # Max 2 passes/day
      class_pass: 2,
      # Max 3 shields/day
      streak_shield: 3,
      # Max 500 XP/day
      referral_xp: 500
    }
  end

  defp calculate_expiry(reward_type) do
    days =
      case reward_type do
        :ai_tutor_minutes -> 30
        :class_pass -> 90
        :streak_shield -> 7
        # Never expires
        :referral_xp -> nil
      end

    if days, do: DateTime.add(DateTimeHelpers.now_for_ecto(), days * 86400), else: nil
  end

  defp count_granted_today(user_id, reward_type) do
    today = DateTimeHelpers.now_for_ecto() |> DateTime.to_date()

    ViralEngine.ViralReward
    |> where([vr], vr.user_id == ^user_id and
                   vr.reward_type == ^to_string(reward_type) and
                   fragment("DATE(?)", vr.inserted_at) == ^today)
    |> select([vr], sum(vr.amount))
    |> Repo.one()
    |> case do
      nil -> 0
      total -> total || 0
    end
  end

  defp update_balances(state, user_id, reward_type, delta) do
    current = get_in(state.user_balances, [user_id, reward_type]) || 0
    put_in(state.user_balances[user_id][reward_type], current + delta)
  end

  defp log_grant(user_id, reward_type, amount, context) do
    Logger.info("Granted #{amount} #{reward_type} to user #{user_id} from #{context[:loop_id]}")
  end

  defp log_redemption(user_id, reward_type, amount) do
    Logger.info("User #{user_id} redeemed #{amount} #{reward_type}")
  end

  defp notify_user(user_id, reward) do
    # Send push notification or in-app message
    Phoenix.PubSub.broadcast(
      ViralEngine.PubSub,
      "user:#{user_id}",
      {:reward_granted, reward}
    )
  end
end
